{Raven} = require(__dirname+'/raven.coffee')
globals = require __dirname+'/models/globals.coffee'
{Commands} = require __dirname+'/clientLib/commands.coffee'
commands = new Commands()
MongoClient = require('mongodb').MongoClient
fs = require('fs')
req = require('request')
https = require('https')
stylus = require('stylus')
nib = require 'nib'
serveStatic = require 'serve-static'
youtubeStream = require('ytdl-core')
DiscordClient = require('./discordClient.js') #my lib :D
express = require "express"
websocketServer = require("ws").Server
globals.wss = new websocketServer({port: 3006})
raven = null
debugLog = ""

connectToSentry = () ->
  globals.raven = new Raven("http://aff861c28dad6d5a7c4f3d60e5ec704e:4cb8957b04daa4d774871fafad470147@188.166.156.69:3001/api",{release: 'd9695b60430ccf9ca9a9f7752c40d640ba1be923', serverName: 'lolstat.net'}, (err, data) ->
    if err
      debugLog += "[!] Error Occured Connecting to Sentry `"+err+"`\n"
    else if data.success
      debugLog += "[i] Connected to Sentry Succesfully\n"
      globals.raven.captureException("Motorbot Initilized",{level: 'info'})
    else
      debugLog += "[!] Error Occured Connecting to Sentry `returned success:false`\n"
  )

globals.dc = new DiscordClient({token: "MTY5NTU0ODgyNjc0NTU2OTMw.CfAmNQ.WebsSsEexNlFWaNc2u54EP-hIX0", debug: true, autorun: true})

stream = null

#Express Setup
app = express()
compile = (str, path) ->
  stylus(str).set('filename',path).use(nib())
app.set('views', __dirname+'/views')
app.set('view engine', 'pug')
app.use(stylus.middleware(
  {src: __dirname + '/static',
  compile: compile
  }
))
app.use(serveStatic(__dirname + '/static'))
app.use(serveStatic(__dirname + '/static/img', { maxAge: 86400000 }))
app.use((req, res, next) ->
  res.setHeader('Access-Control-Allow-Origin', '*')
  res.setHeader('Access-Control-Allow-Methods', 'GET')
  res.setHeader('Access-Control-Allow-Headers', 'X-Requested-With,content-type')
  res.setHeader('Access-Control-Allow-Credentials', true)
  next()
)

#Express Routers
app.use("/", require('./routes/playlist.coffee'))
app.use("/api", require('./routes/api.coffee'))

#redirect for when adding bot
app.get("/redirect", (req, res) ->
  code = req.query.code
  guildId = req.query.guild_id
  console.log req
  res.end(JSON.stringify({guildId: guildId, connected: true}))
)
#create web server for web interface and google chrome extension
server = app.listen(3210)

###
# WebSocket Connection For Web interface
###

###
Websocket Server
###

###privateKey  = fs.readFileSync('/var/www/key.pem', 'utf8')
certificate = fs.readFileSync('/var/www/cert.pem', 'utf8')

credentials = {key: privateKey, cert: certificate}
httpsServer = https.createServer(credentials, app)
httpsServer.listen(3211)

WebSocketServer = require('ws').Server
globals.wss = new WebSocketServer({
  server: httpsServer
})
###
globals.wss.on('connection', (ws) ->
  ws.on('message', (message) ->
    #recieved message
  )
)

globals.wss.broadcast = (data) ->
  globals.wss.clients.forEach((client) ->
    client.send(data)
  )

#create DB Connection
createDBConnection = (cb) ->
  MongoClient.connect('mongodb://localhost:27017/motorbot', (err, db) ->
    if err
      globals.dc.sendMessage("169555395860234240",":name_badge: Fatal Error: I couldn't connect to the motorbot database :cry:")
      throw new Error("Failed to connect to database, exiting")
    debugLog += "[i] Connected to Motorbot Database Succesfully\n"
    globals.db = db
    cb()
  )

#Init Playlist i.e. clear out all playing statuses, incase of hard shutdown/crash
initPlaylist = () ->
  playlistCollection = globals.db.collection("playlist")
  playlistCollection.find({status: "playing"}).sort({timestamp: 1}).toArray((err, results) ->
    for r in results
      trackId = r._id
      playlistCollection.updateOne({'_id': trackId},{'$set':{'status':'played'}},() ->
        console.log("Track Status Changed")
      )
    debugLog += "[i] Initialised Playlist Succesfully\n"
    globals.dc.sendMessage("169555395860234240",":white_check_mark: Hi I'm now online :smiley:\n\n```\n"+debugLog+"\n```")
  )


globals.dc.on("ready", (msg) ->
  d = new Date()
  time = "["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"] "
  console.log(time+msg.user.username+"#"+msg.user.discriminator+" has connected to the gateway server and is at your command")
  connectToSentry()
  createDBConnection(initPlaylist)
  globals.dc.setStatus("with Discord API")
)

globals.dc.on("message", (msg,channel_id,user_id,raw_data) ->
  d = new Date()
  time = "["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"] "
  console.log(time+"\""+msg+"\" sent by user <@"+user_id+"> in <#"+channel_id+">")
  commands.parseMessageForCommand(msg,channel_id,user_id) #parse commands through commands class in clientLib dir
)

#continue through playlist and set status of currently playing track to 'playing' - TODO use ints to identify track status
goThroughVideoList = () ->
  if globals.dc.internals.voice.ready
    playlistCollection = globals.db.collection("playlist")
    playlistCollection.find({status: "added"}).sort({timestamp: 1}).toArray((err, results) ->
      if results[0]
        videoId = results[0].videoId
        channel_id = results[0].channel_id
        title = results[0].title
        trackId = results[0]._id
        if videoId && !globals.dc.internals.voice.allowPlay
          playlistCollection.updateOne({'_id': trackId},{'$set':{'status':'playing'}},() ->
            console.log("Track Status Changed")
          )
          requestUrl = 'http://youtube.com/watch?v=' + videoId
          yStream = youtubeStream(requestUrl,{quality: 'lowest', filter: 'audioonly'})
          yStream.on("error", (e) ->
            globals.raven.captureException(e,{level:'error',tags:{system: 'youtube-stream'}})
            console.log("Error Occured Loading Youtube Video")
          )
          yStream.on("info", (info, format) ->
            volume = 0.5 #set default, as some videos (recently uploaded maybe?) don't have loudness value
            #stabilise volume to avoid really loud or really quiet playback
            if info.loudness
              volume = (parseFloat(info.loudness)/-40.229000916)
              console.log "Setting Volume Based on Video Loudness ("+info.loudness+"): "+volume
            globals.dc.playStream(yStream,{volume: volume})
            dur = globals.convertTimestamp(results[0].duration)
            globals.wss.broadcast(JSON.stringify({type: 'trackUpdate', track: title}))
            globals.dc.sendMessage(channel_id,":play_pause: Now Playing: "+title+" ("+dur+")")
            console.log("Now Playing: "+title)
          )
    )
  else
    globals.dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")

#once song is done, re-organise playlist and play next if available
globals.songDone = (goToNext = false) ->
  if globals.dc.internals.voice.ready
    console.log("Song Done")
    playlistCollection = globals.db.collection("playlist")
    playlistCollection.find({status: "playing"}).sort({timestamp: 1}).toArray((err, results) ->
      if results[0]
        trackId = results[0]._id
        playlistCollection.updateOne({'_id': trackId},{'$set':{'status':'played'}},() ->
          console.log("Track Status Changed")
          if goToNext
            setTimeout(goThroughVideoList,1000)
        )
      else
        if goToNext
          setTimeout(goThroughVideoList,1000)
    )

globals.dc.on("songDone", () ->
  globals.songDone(true)
)

globals.dc.on("status", (user_id,status,game,raw_data) ->
  d = new Date()
  time = "["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"] "
  if status == "online"
    console.log(time+"<@"+user_id+"> is now online")
  else if status == "idle"
    console.log(time+"<@"+user_id+"> is now idle")
  else if status == "offline"
    console.log(time+"<@"+user_id+"> has gone offline, bye bye :(")
  else
    console.log(time+"<@"+user_id+"> has an unknown status?")

  if game != null && status == "online"
    console.log(time+"<@"+user_id+"> is now playing "+game["name"])
)

###
# Other Methods
###

millisecondsToStr = (milliseconds) ->
  numberEnding = (number) ->
    if number > 1 then 's' else ''
  temp = Math.floor(milliseconds / 1000)
  years = Math.floor(temp / 31536000)
  if years
    return years + ' year' + numberEnding(years)
  days = Math.floor((temp %= 31536000) / 86400)
  if days
    return days + ' day' + numberEnding(days)
  hours = Math.floor((temp %= 86400) / 3600)
  if hours
    return hours + ' hour' + numberEnding(hours)
  minutes = Math.floor((temp %= 3600) / 60)
  if minutes
    return minutes + ' minute' + numberEnding(minutes)
  seconds = temp % 60
  if seconds
    return seconds + ' second' + numberEnding(seconds)
  return 'less than a second'

getParameterByName = (name, url) ->
  if (!url)
    url = window.location.href
  name = name.replace(/[\[\]]/g, "\\$&")
  regex = new RegExp("[?&]" + name + "(=([^&#]*)|&|#|$)")
  results = regex.exec(url)
  if (!results)
    return null
  if (!results[2])
    return ''
  return decodeURIComponent(results[2].replace(/\+/g, " "))
