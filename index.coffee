Raven = require __dirname+'/raven.coffee'
globals = require __dirname+'/models/globals.coffee'
Commands = require __dirname+'/clientLib/commands.coffee'
MongoClient = require('mongodb').MongoClient
fs = require 'fs'
req = require 'request'
https = require 'https'
stylus = require 'stylus'
nib = require 'nib'
serveStatic = require 'serve-static'
youtubeStream = require 'ytdl-core'
DiscordClient = require './discordClient.js' #my lib :D
express = require "express"
websocketServer = require("ws").Server
globals.wss = new websocketServer({port: 3006}) #public port is 3211 and local 3006 via nginx proxy
raven = null
debugLog = ""
keys = require __dirname+'/keys.json'

globals.dc = new DiscordClient({token: keys.token, debug: true, autorun: true})

stream = null
connectedChannel = null
warning = false
commands = null

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

globals.wss.on('connection', (ws) ->
  ws.on('message', (message) ->
    #recieved message
  )
)

globals.wss.broadcast = (data) ->
  globals.wss.clients.forEach((client) ->
    client.send(data, (err) ->
      if err then console.log err
    )
  )

#create DB Connection
createDBConnection = (cb) ->
  MongoClient.connect('mongodb://localhost:27017/motorbot', (err, db) ->
    if err
      globals.dc.sendMessage("169555395860234240",":name_badge: Fatal Error: I couldn't connect to the motorbot database :cry:")
      throw new Error("Failed to connect to database, exiting")
    debugLog += "+ [i] Connected to MotorBot Database Successfully\n"
    globals.db = db
    cb()
  )

#Init Playlist i.e. clear out all playing statuses, incase of hard shutdown/crash
initPlaylist = () ->
  songQueueCollection = globals.db.collection("songQueue")
  songQueueCollection.find({status: "playing"}).toArray((err, results) ->
    if err then console.log err
    for r in results
      trackId = r._id
      songQueueCollection.updateOne({'_id': trackId},{'$set':{'status':'played'}},() ->
        console.log("Track Status Changed")
      )
    debugLog += "+ [i] Initialised Playlist Successfully\n"
    globals.dc.sendMessage("169555395860234240",":black_joker: Hi, I'm now online\n\n```diff\n"+debugLog+"\n```")
    globals.dc.setStatus("with Discord API")
    debugLog = ""
    warning = false
  )


globals.dc.on("ready", (msg) ->
  d = new Date()
  time = "["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"] "
  console.log(time+msg.user.username+"#"+msg.user.discriminator+" has connected to the gateway server and is at your command")
  commands = new Commands()
  createDBConnection(initPlaylist)
  if globals.connectedChannel
    console.log "Attempt to reconnect to voice channel: "+globals.connectedChannel
    guild_id = "130734377066954752"
    globals.dc.joinVoice(connectedChannel, guild_id)
)

globals.dc.on("message", (msg,channel_id,user_id,raw_data) ->
  commands.parseMessageForCommand(msg,channel_id,user_id) #parse commands through commands class in clientLib dir
)

globals.dc.on("disconnect", () ->
  ###if !warning
    warning = true
    globals.dc.sendMessage("169555395860234240",":warning: The connection to the Main Gateway Server `"+globals.dc.internals.gateway+"` Unexpectedly Closed! I will try to reconnect automatically :smiley:")
    globals.raven.captureException("The connection to the Gateway Server Unexpectedly Closed",{level: "warn", tags:[{instigator: 'discord'}]})
    connectedChannel = globals.dc.internals.voice.channel_id###
)

globals.dc.on("voiceClosed", () ->
  console.log globals.dc.internals.voice.channel_id
  if globals.dc.internals.voice.channel_id != undefined #check if unexpected leave
    globals.dc.sendMessage("169555395860234240",":warning: The connection to the Voice Gateway Server `"+globals.dc.internals.voice.endpoint+"` Unexpectedly Closed! Discord is encountering issues, please try again later :cry:")
    raven.captureException("The connection to the Voice Gateway Server Unexpectedly Closed",{level: "warn", tags:[{instigator: 'discord'}]})
    guild_id = "130734377066954752"
    globals.dc.leaveVoice(guild_id)
)

streamNewTrack = (results) ->
  songQueueCollection = globals.db.collection("songQueue")
  if results[0]
    videoId = results[0].videoId
    title = results[0].title
    trackId = results[0]._id
    playlistId = results[0].playlistId
    song = results[0]
    if videoId && !globals.dc.internals.voice.allowPlay
      songQueueCollection.updateOne({'_id': trackId, 'playlistId': playlistId},{'$set':{'status':'playing'}},() ->
        console.log("Track Status Changed")
      )
      requestUrl = 'http://youtube.com/watch?v=' + videoId
      yStream = youtubeStream(requestUrl,{quality: 'lowest', filter: 'audioonly'})
      yStream.on("error", (e) ->
        console.log("Error Occurred Loading Youtube Video")
        globals.songComplete(true)
      )
      yStream.on("info", (info, format) ->
        volume = 0.6 #set default, as some videos (recently uploaded maybe?) don't have loudness value
        #stabilise volume to avoid really loud or really quiet playback
        if info.loudness
          volume = (parseFloat(info.loudness)/-27)
          console.log "Setting Volume Based on Video Loudness ("+info.loudness+"): "+volume
        globals.dc.playStream(yStream,{volume: volume})
        dur = globals.convertTimestamp(results[0].duration)
        globals.wss.broadcast(JSON.stringify({type: 'playUpdate', status: 'play'}))
        globals.wss.broadcast(JSON.stringify({type: 'trackUpdate', song: song}))
        globals.dc.setStatus(title)
        globals.isPlayling = true
        console.log("Now Playing: "+title)
      )
  

goThroughSongQueue = () ->
  songQueueCollection = globals.db.collection("songQueue")
  songQueueCollection.find({status: "queued"}).toArray((err, results) ->
    if err then console.log err
    if results[0]
      streamNewTrack(results)
    else
      #no songs in queue, go to nextSong
      if globals.randomPlayback
        songQueueCollection.find({status: "added"}).sort({randId: 1}).toArray((err, results) ->
          if err then console.log err
          streamNewTrack(results)
        )
      else
        songQueueCollection.find({status: "added"}).toArray((err, results) ->
          if err then console.log err
          streamNewTrack(results)
        )
  )

globals.songComplete = (goToNext) ->
  if globals.dc.internals.voice.ready && !globals.dc.internals.voice.pause
    console.log("Song Complete")
    globals.isPlayling = false
    songQueueCollection = globals.db.collection("songQueue")
    songQueueCollection.find({status: "playing"}).sort({timestamp: 1}).toArray((err, results) ->
      if err then console.log err
      if results[0]
        trackId = results[0]._id
        playlistId = results[0].playlistId
        songQueueCollection.updateOne({'_id': trackId, 'playlistId': playlistId},{'$set':{'status':'played'}},() ->
          console.log("Track Status Changed")
          if goToNext
            setTimeout(goThroughSongQueue,1000)
        )
      else
        if goToNext
          setTimeout(goThroughSongQueue,1000)
    )

globals.dc.on("songDone", () ->
  globals.wss.broadcast(JSON.stringify({type: 'songDone'}))
  globals.songComplete(true)
)
startTime = 0
globals.dc.on("songTime", (time) ->
  if time < 1000
    startTime = 0
  if time >= startTime+1000
    startTime += 1000
    globals.wss.broadcast(JSON.stringify({type: 'songTime', time: time}))
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
