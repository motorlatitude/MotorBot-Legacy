{Raven} = require(__dirname+'/raven.coffee')
globals = require __dirname+'/models/globals.coffee'
MongoClient = require('mongodb').MongoClient
req = require('request')
fs = require('fs')
stylus = require('stylus')
nib = require 'nib'
serveStatic = require 'serve-static'
apiai = require('apiai')
url_module = require('url')
apiai = apiai("ea1bdb33a83f48c795a585e44a4cdb4b")
youtubeStream = require('ytdl-core')
DiscordClient = require('./discordClient.js') #my lib :D
express = require "express"
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

#Create Server

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

onError = (err, req, res, next) ->
  res.statusCode = 500
  res.end(res.sentry+'\n')

app.use("/", require('./routes/playlist.coffee'))
app.use("/api", require('./routes/api.coffee'))

app.get("/redirect", (req, res) ->
  code = req.query.code
  guildId = req.query.guild_id
  console.log req
  res.end(JSON.stringify({guildId: guildId, connected: true}))
)

server = app.listen(3210)

createDBConnection = (cb) ->
  MongoClient.connect('mongodb://localhost:27017/motorbot', (err, db) ->
    if err
      globals.dc.sendMessage("169555395860234240",":name_badge: Fatal Error: I couldn't connect to the motorbot database :cry:")
      throw new Error("Failed to connect to database, exiting")
    debugLog += "[i] Connected to Motorbot Database Succesfully\n"
    globals.db = db
    cb()
  )

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
  if msg == "!api sid"
    console.log(time+"API Command")
    msg = "\`\`\`Javascript\nDiscordClient.prototype.internals.sequence = "+globals.dc.internals.sequence+"\n\`\`\`"
    globals.dc.sendMessage(channel_id,msg)
  else if msg == "!api vsid"
    console.log(time+"API Command")
    msg = "\`\`\`Javascript\nDiscordClient.prototype.internals.voice.sequence = "+globals.dc.internals.voice.sequence+"\n\`\`\`"
    globals.dc.sendMessage(channel_id,msg)
  else if msg == "!api ssrc"
    console.log(time+"API Command")
    msg = "\`\`\`Javascript\nDiscordClient.prototype.internals.voice.ssrc = "+globals.dc.internals.voice.ssrc+"\n\`\`\`"
    globals.dc.sendMessage(channel_id,msg)
  else if msg == "!api status"
    console.log(time+"API Command")
    voice = "Not Connected"
    if globals.dc.internals.voice.endpoint
      voice = globals.dc.internals.voice.endpoint
    msg = "All is clear, I'm current connected to Discord Server and everything seems fine :smile:\n\n\`\`\`Javascript\nConnected to Server: \""+globals.dc.internals.gateway+"\"\nMy ID is: "+globals.dc.internals.user_id+"\nConnected to Voice Server: "+voice+"\n\`\`\`"
    globals.dc.sendMessage(channel_id,msg)
  else if msg == "!os"
    msg = "\`\`\`Javascript\n{\n\tplatform: \""+globals.dc.internals.os.platform()+"\",\n\trelease: "+globals.dc.internals.os.release()+",\n\ttype: \""+globals.dc.internals.os.type()+"\",\n\tloadAvg: "+globals.dc.internals.os.loadavg()+",\n\thostname: \""+globals.dc.internals.os.hostname()+"\",\n\tmemory: \""+Math.round((parseFloat(globals.dc.internals.os.freemem()/1000000)))+"MB / "+Math.round((parseFloat(globals.dc.internals.os.totalmem())/1000000))+"MB\",\n\tarch: "+globals.dc.internals.os.arch()+",\n\tcpus: "+JSON.stringify(globals.dc.internals.os.cpus(), null, '\t')+"\n}\n\`\`\`"
    globals.dc.sendMessage(channel_id,msg)
  else if msg == "!os uptime"
    msg = "Server Uptime: "+millisecondsToStr(parseFloat(globals.dc.internals.os.uptime())*1000)
    globals.dc.sendMessage(channel_id,msg)
  else if msg.match(/cum\son\sme/)
    globals.dc.sendMessage(channel_id,"8====D- -- - (O)")
  else if msg.match(/^!status\s/)
    stt = msg.replace(/!status\s/,"")
    globals.dc.setStatus(stt)
  else if msg.match(/\!random/)
    globals.dc.sendMessage(channel_id,"Random Number: "+(Math.round((Math.random()*100))))
  else if msg.match(/goodnight/gmi)
    globals.dc.sendMessage(channel_id,":sparkles: Good Night <@"+user_id+">")
  else if msg.match(/heads\sor\stails(\?|)/gmi)
    if Math.random() >= 0.5
      globals.dc.sendMessage(channel_id,":one: Heads <@"+user_id+">")
    else
      globals.dc.sendMessage(channel_id,":zero: Tails <@"+user_id+">")
  else if msg.match(/^!ban doug/gmi)
    globals.dc.sendMessage(channel_id,"If only I could :rolling_eyes: <@"+user_id+">")
  else if msg.match(/fight\sme(\sbro|)/gmi) || msg.match(/come\sat\sme(\sbro|)/gmi)
    globals.dc.sendMessage(channel_id,"(ง’̀-‘́)ง")
  else if msg.match(/^!help/gmi)
    globals.dc.sendMessage(channel_id,"<@"+user_id+"> Check this out: https://github.com/motorlatitude/MotorBot/blob/master/README.md")
  else if msg.match(/^!lolstat(\s|\.euw|\.na|\.br|\.eune|\.kr|\.lan|\.las|\.oce|\.ru|\.tr|\.jp)/gmi)
    region = "euw"
    if msg.replace(/^!lolstat/gmi,"").indexOf(".") > -1
      region = msg.replace(/^!lolstat/gmi,"").split(".")[1].split(/\s/gmi)[0]
    summoner = encodeURI(msg.replace(/^!lolstat(\s|\.euw|\.na|\.br|\.eune|\.kr|\.lan|\.las|\.oce|\.ru|\.tr|\.jp)/gmi,"").replace(/\s/gmi,"").toLowerCase())
    globals.dc.sendFile(channel_id,req('https://api.lolstat.net/discord/profile/'+summoner+'/'+region),"",false)
  else if msg.match(/\!voice\s/)
    command = msg.replace(/\!voice\s/,"")
    guild_id = "130734377066954752"
    if command.match(/join/)
      chnl = command.replace(/join\s/,"")
      chnl_id = null
      console.log(chnl)
      for channel in globals.dc.servers[guild_id].channels
        if chnl == channel.name && channel.type == "voice"
          chnl_id = channel.id
      if chnl_id == null
        chnl = "General"
        for channel in globals.dc.servers[guild_id].channels
          if chnl == channel.name && channel.type == "voice"
            chnl_id = channel.id
      globals.dc.joinVoice(chnl_id,guild_id)
    else if command.match(/leave/)
      globals.dc.leaveVoice(guild_id)
  else if msg.match(/^!music\s/)
    if globals.dc.internals.voice.ready
      videoId = msg.split(" ")[1]
      if videoId == "stop"
        globals.dc.stopStream()
        globals.songDone()
      else if videoId == "add"
        videoId = msg.split(" ")[2]
        if videoId.indexOf('https://') > -1
          videoId = getParameterByName("v",videoId)
        req.get({
          url: "https://www.googleapis.com/youtube/v3/videos?id="+videoId+"&key=AIzaSyAyoWcB_yzEqESeJm-W_eC5QDcOu5R1M90&part=snippet,contentDetails",
          headers: {
            "Content-Type": "application/json"
          }
        }, (err, httpResponse, body) ->
          if err
            globals.raven.captureException(err,{level:'error',request: httpResponse})
            return console.error('Error Occured Fetching Youtube Metadata')
          data = JSON.parse(body)
          if data.items
            if data.items[0]
              console.log(videoId)
              playlistCollection = globals.db.collection("playlist")
              playlistCollection.insertOne({videoId: videoId, title: data.items[0].snippet.title, duration: data.items[0].contentDetails.duration, channel_id: channel_id, timestamp: new Date().getTime(), status: 'added'}, (err, result) ->
                if err
                  globals.raven.captureException(err,{level:'error'})
                  globals.dc.sendMessage(channel_id,":warning: A database error occurred adding this track...\nReport sent to sentry, please notify admin of the following error: \`Database insertion error at line 323: "+err.toString()+"\`")
                else
                  globals.dc.sendMessage(channel_id,":notes: Added "+data.items[0].snippet.title)
                  goThroughVideoList(channel_id)
              )
            else
              globals.raven.captureException(new Error("Youtube Error: Googleapis returned video not found for videoId"),{level:'error',extra:{videoId: videoId},request: httpResponse})
              globals.dc.sendMessage(channel_id,":warning: Youtube Error: Googleapis returned video not found for videoId ("+videoId+")")
          else
            globals.raven.captureException(new Error("Youtube Error: Googleapis returned video not found for videoId"),{level:'error',extra:{videoId: videoId},request: httpResponse})
            globals.dc.sendMessage(channel_id,":warning: Youtube Error: Googleapis returned video not found for videoId ("+videoId+")")
        )
      else if videoId == "prev"
        playlistCollection = globals.db.collection("playlist")
        playlistCollection.find({status: {$ne: 'added'}}).sort({timestamp: 1}).toArray((err, results) ->
          lastResult = results[results.length-1]
          secondLastResult = results[results.length-2]
          if lastResult.status == "playing"
            playlistCollection.updateOne({_id: lastResult._id},{$set: {status: 'added'}},(err, result) ->
              if err
                console.log("Databse Updated Error Occured")
              else
                playlistCollection.updateOne({_id: secondLastResult._id},{$set: {status: 'added'}},(err, result) ->
                  if err
                    console.log("Databse Updated Error Occured")
                  else
                    globals.dc.stopStream()
                    setTimeout(goThroughVideoList,1000)
                )
            )
          else
            playlistCollection.updateOne({_id: lastResult._id},{$set: {status: 'added'}},(err, result) ->
              if err
                console.log("Databse Updated Error Occured")
              else
                globals.dc.stopStream()
                setTimeout(goThroughVideoList,1000)
            )
        )
      else if videoId == "skip"
        globals.dc.stopStream()
        globals.songDone()
      else if videoId == "play"
        goThroughVideoList()
      else if videoId == "list"
        playlistCollection = globals.db.collection("playlist")
        playlistCollection.find({status: "added"}).sort({timestamp: 1}).toArray((err, results) ->
          if err
            globals.raven.captureException(err,{level:'error'})
            globals.dc.sendMessage(channel_id,":warning: A database error occurred whilst listing all tracks...\nReport sent to sentry, please notify admin of the following error: \`playlistCollection Error at line 239\`")
          else
            if(results.length > 0)
              songNames = []
              for r in results
                songTitle = r.title
                songNames.push(songTitle)
              globals.dc.sendMessage(channel_id,":headphones: Playlist can be viewed here: https://mb.lolstat.net/")
            else
              globals.dc.sendMessage(channel_id,"No songs are currently in the playlist :grinning:")
        )
      else
        globals.dc.sendMessage(channel_id,"Unknown Voice Command :cry:")
    else
      globals.dc.sendMessage(channel_id,"Hmmmmm, I think you might want to join a Voice Channel first :wink:")
  else if msg.match(/^!volume\s/)
    if globals.dc.internals.voice.ready
      if user_id == "95164972807487488"
        globals.dc.internals.voice.volume = parseFloat(msg.split(/\s/)[1])
      else
        globals.dc.sendMessage("169555395860234240","Sorry, you're not authorised for this command :cry:")
    else
      globals.dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")
  else if msg.match(/^!sb\spog/)
    if globals.dc.internals.voice.ready
      globals.dc.stopStream()
      globals.songDone()
      setTimeout(() ->
        globals.dc.playStream(__dirname+'/soundboard/play of the game.mp3',{volume: 3.0})
      ,1000)
    else
      globals.dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")
  else if msg.match(/^!sb\swonder/)
    if globals.dc.internals.voice.ready
      globals.dc.stopStream()
      globals.songDone()
      setTimeout(() ->
        globals.dc.playStream(__dirname+'/soundboard/wonder.mp3',{volume: 3.0})
      ,1000)
    else
      globals.dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")
  else if msg.match(/^!sb\s1/)
    if globals.dc.internals.voice.ready
      globals.dc.stopStream()
      globals.songDone()
      setTimeout(() ->
        globals.dc.playStream(__dirname+'/soundboard/1.mp3',{volume: 3.0})
      ,1000)
    else
      globals.dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")
  else if msg.match(/^!sb\s2/)
    if globals.dc.internals.voice.ready
      globals.dc.stopStream()
      setTimeout(() ->
        globals.dc.playStream(__dirname+'/soundboard/2.mp3',{volume: 3.0})
      ,1000)
    else
      globals.dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")
  else if msg.match(/^!sb\s3/)
    if globals.dc.internals.voice.ready
      globals.dc.stopStream()
      globals.songDone()
      setTimeout(() ->
        globals.dc.playStream(__dirname+'/soundboard/3.mp3',{volume: 3.0})
      ,1000)
    else
      globals.dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")
  else if msg.match(/^!sb\sgp/)
    if globals.dc.internals.voice.ready
      globals.dc.stopStream()
      globals.songDone()
      setTimeout(() ->
        globals.dc.playStream(__dirname+'/soundboard/gp.mp3',{volume: 3.0})
      ,1000)
    else
      globals.dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")
  else if msg.match(/^!sb\sj3/)
    if globals.dc.internals.voice.ready
      globals.dc.stopStream()
      globals.songDone()
      setTimeout(() ->
        globals.dc.playStream(__dirname+'/soundboard/justice 3.mp3',{volume: 3.0})
      ,1000)
    else
      globals.dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")
  else if msg.match(/^!sb\ssb/)
    if globals.dc.internals.voice.ready
      globals.dc.stopStream()
      setTimeout(() ->
        globals.dc.playStream(__dirname+'/soundboard/speed boost.mp3',{volume: 3.0})
      ,1000)
    else
      globals.dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")
  else if msg.match(/^!sb\swsr/)
    if globals.dc.internals.voice.ready
      globals.dc.stopStream()
      globals.songDone()
      setTimeout(() ->
        globals.dc.playStream(__dirname+'/soundboard/wsr.mp3',{volume: 1.0})
      ,1000)
    else
      globals.dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")
  else if msg.match(/^!sb\saffirmative/)
    if globals.dc.internals.voice.ready
      globals.dc.stopStream()
      globals.songDone()
      setTimeout(() ->
        globals.dc.playStream(__dirname+'/soundboard/affirmative.mp3',{volume: 3.0})
      ,1000)
    else
      globals.dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")
  else if msg.match(/^!talk\s/)
    console.log("Talk Command Issued")
    request = apiai.textRequest(msg.replace(/^!talk\s/,""))
    request.on('response', (response) ->
      console.log(response)
      globals.dc.sendMessage(channel_id,response.result.fulfillment.speech)
    )
    request.on('error', (error) ->
      globals.raven.captureException(error,{level:'error'})
      console.log(error)
    )
    request.end()
  else if msg.match(/^!/)
    globals.dc.sendMessage(channel_id,"I don't know what you want :cry:")
)

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
            volume = 0.5
            if info.loudness
              volume = (parseFloat(info.loudness)/-40.229000916)
              console.log "Setting Volume Based on Video Loudness ("+info.loudness+"): "+volume
            globals.dc.playStream(yStream,{volume: volume})
            dur = globals.convertTimestamp(results[0].duration)
            globals.dc.sendMessage(channel_id,":play_pause: Now Playing: "+title+" ("+dur+")")
            console.log("Now Playing: "+title)
          )
    )
  else
    globals.dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")

globals.songDone = () ->
  if globals.dc.internals.voice.ready
    console.log("Song Done")
    playlistCollection = globals.db.collection("playlist")
    playlistCollection.find({status: "playing"}).sort({timestamp: 1}).toArray((err, results) ->
      if results[0]
        trackId = results[0]._id
        playlistCollection.updateOne({'_id': trackId},{'$set':{'status':'played'}},() ->
          console.log("Track Status Changed")
          setTimeout(goThroughVideoList,1000)
        )
      else
        setTimeout(goThroughVideoList,1000)
    )

globals.dc.on("songDone", globals.songDone)

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
