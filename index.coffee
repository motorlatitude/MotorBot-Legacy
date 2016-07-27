{Raven} = require(__dirname+'/raven.coffee')
req = require('request')
fs = require('fs')
stylus = require('stylus')
nib = require 'nib'
serveStatic = require 'serve-static'
apiai = require('apiai')
url_module = require('url')
https = require('https')
apiai = apiai("ea1bdb33a83f48c795a585e44a4cdb4b")
DiscordClient = require('./discordClient.js')
youtubeStream = require('ytdl-core')
raven = null
connectToSentry = () ->
  raven = new Raven("http://aff861c28dad6d5a7c4f3d60e5ec704e:4cb8957b04daa4d774871fafad470147@188.166.156.69:3001/api",{release: 'd9695b60430ccf9ca9a9f7752c40d640ba1be923', serverName: 'lolstat.net'}, (err, data) ->
    if err
      dc.sendMessage("169555395860234240",":warning: Error Occured Connecting to Sentry `"+err+"`")
    else if data.success
      dc.sendMessage("169555395860234240",":white_check_mark: Connected to :shield: Sentry Succesfully")
      raven.captureException("Motorbot Initilized",{level: 'info'})
    else
      dc.sendMessage("169555395860234240",":warning: Error Occured Connecting to Sentry `returned success:false`")
  )


dc = new DiscordClient({token: "MTY5NTU0ODgyNjc0NTU2OTMw.CfAmNQ.WebsSsEexNlFWaNc2u54EP-hIX0", debug: true, autorun: true})
stream = null

#Create Server
express = require "express"
MongoClient = require('mongodb').MongoClient

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

convertTimestamp = (input) ->
  reptms = /^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$/
  hours = 0
  minutes = 0
  seconds = 0

  if reptms.test(input)
    matches = reptms.exec(input)
    if (matches[1]) then hours = Number(matches[1])
    if (matches[2]) then minutes = Number(matches[2])
    if (matches[3]) then seconds = Number(matches[3])
    if (minutes < 10) then minutes = "0"+minutes
    if (seconds < 10) then seconds = "0"+seconds
  if hours == 0
    return minutes+":"+seconds
  else
    return hours+":"+minutes+":"+seconds

app.get("/", (req, res) ->
  playlistCollection = app.locals.db.collection("playlist")
  playlistCollection.find({status: "added"}).sort({timestamp: 1}).toArray((err, results) ->
    if results[0]
      for r in results
        r.formattedTimestamp = convertTimestamp(r.duration)
      res.render('playlist',{playlist:results})
    else
      res.render('playlist',{playlist:{}})
  )
)

app.get("/redirect", (req, res) ->
  code = req.query.code
  guildId = req.query.guild_id
  console.log req
  res.end(JSON.stringify({guildId: guildId, connected: true}))
)

oauth2 = require('simple-oauth2')({
  clientID: "169554794376200192",
  clientSecret: "5XyBGU-YtwVTMOQHKpbxUvmnYF4tx-At",
  site: 'https://discordapp.com/api',
  tokenPath: '/oauth2/token',
  authorizationPath: '/oauth2/authorize'
})

authorization_uri = oauth2.authCode.authorizeURL({
  redirect_uri: 'https://mb.lolstat.net/callback',
  scope: 'identify email guilds'
})

app.get('/userAuth', (req, res) ->
  res.render('userAuth',{})
)

app.get('/auth', (req, res) ->
  res.redirect(authorization_uri)
)

app.get('/callback', (request, res) ->
  console.log "Callback called"
  code = request.query.code
  console.log code
  oauth2.authCode.getToken({
    code: code,
    redirect_uri: 'https://mb.lolstat.net/callback'
  }, (error, result) ->
    console.log "Save Token"
    if (error)
      console.log('Access Token Error', error.message)
    token = oauth2.accessToken.create(result)
    console.log token.token
    console.log "Access Token -> "+token.token.access_token
    req.get({
      url: "https://discordapp.com/api/users/@me/guilds",
      headers: {
        "Authorization": "Bearer "+token.token.access_token
        "Content-Type": "application/json"
      }
    }, (err, httpResponse, body) ->
      foundGuild = false
      for guild in JSON.parse(body)
        console.log guild.id
        if guild.id == "130734377066954752"
          foundGuild = true
          break
      if foundGuild
        req.get({
          url: "https://discordapp.com/api/users/@me",
          headers: {
            "Authorization": "Bearer "+token.token.access_token
            "Content-Type": "application/json"
          }
        }, (err, httpResponse, body) ->
          if err
            res.end("Sorry, Unknown Error Occured")
          body = JSON.parse(body)
          console.log body
          res.redirect('/authSuccess?user='+body.id+'&name='+body.username)
          res.end("Success, you're in KTJ and allowed to add songs")
        )
      else
        res.end("Sorry, you're not a member of KTJ :(")
    )
  )
)

app.get('/authSuccess', (req, res) ->
  userId = req.query.user
  userName = req.query.name
  res.render('authSuccess',{userId:userId,userName:userName})
)

app.get('/token', (req, res) ->
  res.end("Token")
)

app.get("/api/playlist/:videoId", (request,res) ->
  console.log("Added Item to Playlist")
  videoId = request.params.videoId || ""
  userId = request.query.userId || ""
  channel_id = "169555395860234240" # api_channel otherwise we have to get the user to oAuth, bit of a pain so don't bother
  req.get({
    url: "https://www.googleapis.com/youtube/v3/videos?id="+videoId+"&key=AIzaSyAyoWcB_yzEqESeJm-W_eC5QDcOu5R1M90&part=snippet,contentDetails",
    headers: {
      "Content-Type": "application/json"
    }
  }, (err, httpResponse, body) ->
    if err
      raven.captureException(err,{level:'error',request: httpResponse})
      return console.error('Error Occured Fetching Youtube Metadata')
    data = JSON.parse(body)
    if data.items[0]
      console.log(videoId)
      playlistCollection = app.locals.db.collection("playlist")
      playlistCollection.insertOne({videoId: videoId, title: data.items[0].snippet.title, duration: data.items[0].contentDetails.duration, channel_id: channel_id, timestamp: new Date().getTime(), status: 'added', userId: userId}, (err, result) ->
        if(err)
          raven.captureException(err,{level:'error'})
          dc.sendMessage(channel_id,":warning: A database error occurred adding this track... <@"+userId+">\nReport sent to sentry, please notify admin of the following error: \`Database insertion error at line 194: "+err.toString()+"\`")
        else
          dc.sendMessage(channel_id,":notes: Added "+data.items[0].snippet.title+" <@"+userId+">")
          goThroughVideoList(channel_id)
          res.end(JSON.stringify({added: true}))
      )
    else
      raven.captureException(new Error("Youtube Error: Googleapis returned video not found for videoId"),{level:'error',extra:{videoId: videoId},request: httpResponse})
      dc.sendMessage(channel_id,":warning: Youtube Error: Googleapis returned video not found for videoId ("+videoId+")")
      res.end(JSON.stringify({added: false, error: "Youtube Error"}))
  )
)

server = app.listen(3210)

createDBConnection = () ->
  MongoClient.connect('mongodb://localhost:27017/motorbot', (err, db) ->
    if err
      dc.sendMessage("169555395860234240",":name_badge: Fatal Error: I couldn't connect to the motorbot database :cry:")
      throw new Error("Failed to connect to database, exiting")
    dc.sendMessage("169555395860234240",":white_check_mark: Connected to Motorbot Database Succesfully")
    app.locals.db = db
  )

dc.on("ready", (msg) ->
  d = new Date()
  time = "["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"] "
  console.log(time+msg.user.username+"#"+msg.user.discriminator+" has connected to the gateway server and is at your command")
  connectToSentry()
  createDBConnection()
  dc.sendMessage("169555395860234240",":white_check_mark: Hi, I'm now online :smiley:")
  dc.setStatus("with Discord API")
)

dc.on("message", (msg,channel_id,user_id,raw_data) ->
  d = new Date()
  time = "["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"] "
  console.log(time+"\""+msg+"\" sent by user <@"+user_id+"> in <#"+channel_id+">")
  if msg == "!api sid"
    console.log(time+"API Command")
    msg = "\`\`\`Javascript\nDiscordClient.prototype.internals.sequence = "+dc.internals.sequence+"\n\`\`\`"
    dc.sendMessage(channel_id,msg)
  else if msg == "!api ssrc"
    console.log(time+"API Command")
    msg = "\`\`\`Javascript\nDiscordClient.prototype.internals.voice.ssrc = "+dc.internals.voice.ssrc+"\n\`\`\`"
    dc.sendMessage(channel_id,msg)
  else if msg == "!api status"
    console.log(time+"API Command")
    voice = "Not Connected"
    if dc.internals.voice.endpoint
      voice = dc.internals.voice.endpoint
    msg = "All is clear, I'm current connected to Discord Server and everything seems fine :smile:\n\n\`\`\`Javascript\nConnected to Server: \""+dc.internals.gateway+"\"\nMy ID is: "+dc.internals.user_id+"\nConnected to Voice Server: "+voice+"\n\`\`\`"
    dc.sendMessage(channel_id,msg)
  else if msg == "!os"
    msg = "\`\`\`Javascript\n{\n\tplatform: \""+dc.internals.os.platform()+"\",\n\trelease: "+dc.internals.os.release()+",\n\ttype: \""+dc.internals.os.type()+"\",\n\tloadAvg: "+dc.internals.os.loadavg()+",\n\thostname: \""+dc.internals.os.hostname()+"\",\n\tmemory: \""+Math.round((parseFloat(dc.internals.os.freemem()/1000000)))+"MB / "+Math.round((parseFloat(dc.internals.os.totalmem())/1000000))+"MB\",\n\tarch: "+dc.internals.os.arch()+",\n\tcpus: "+JSON.stringify(dc.internals.os.cpus(), null, '\t')+"\n}\n\`\`\`"
    dc.sendMessage(channel_id,msg)
  else if msg == "!os uptime"
    msg = "Server Uptime: "+millisecondsToStr(parseFloat(dc.internals.os.uptime())*1000)
    dc.sendMessage(channel_id,msg)
  else if msg.match(/cum\son\sme/)
    dc.sendMessage(channel_id,"8====D- -- - (O)")
  else if msg.match(/^!status\s/)
    stt = msg.replace(/!status\s/,"")
    dc.setStatus(stt)
  else if msg.match(/\!random/)
    dc.sendMessage(channel_id,"Random Number: "+(Math.round((Math.random()*100))))
  else if msg.match(/goodnight/gmi)
    dc.sendMessage(channel_id,":sparkles: Good Night <@"+user_id+">")
  else if msg.match(/heads\sor\stails(\?|)/gmi)
    if Math.random() >= 0.5
      dc.sendMessage(channel_id,":one: Heads <@"+user_id+">")
    else
      dc.sendMessage(channel_id,":zero: Tails <@"+user_id+">")
  else if msg.match(/^!ban doug/gmi)
    dc.sendMessage(channel_id,"If only I could :rolling_eyes: <@"+user_id+">")
  else if msg.match(/fight\sme(\sbro|)/gmi) || msg.match(/come\sat\sme(\sbro|)/gmi)
    dc.sendMessage(channel_id,"(ง’̀-‘́)ง")
  else if msg.match(/^!help/gmi)
    dc.sendMessage(channel_id,"<@"+user_id+"> Check this out: https://github.com/motorlatitude/MotorBot/blob/master/README.md")
  else if msg.match(/^!lolstat(\s|\.euw|\.na|\.br|\.eune|\.kr|\.lan|\.las|\.oce|\.ru|\.tr|\.jp)/gmi)
    region = "euw"
    if msg.replace(/^!lolstat/gmi,"").indexOf(".") > -1
      region = msg.replace(/^!lolstat/gmi,"").split(".")[1].split(/\s/gmi)[0]
    summoner = encodeURI(msg.replace(/^!lolstat(\s|\.euw|\.na|\.br|\.eune|\.kr|\.lan|\.las|\.oce|\.ru|\.tr|\.jp)/gmi,"").replace(/\s/gmi,"").toLowerCase())
    dc.sendFile(channel_id,req('https://api.lolstat.net/discord/profile/'+summoner+'/'+region),"",false)
  else if msg.match(/\!voice\s/)
    command = msg.replace(/\!voice\s/,"")
    guild_id = "130734377066954752"
    if command.match(/join/)
      chnl = command.replace(/join\s/,"")
      chnl_id = null
      console.log(chnl)
      for channel in dc.servers[guild_id].channels
        if chnl == channel.name && channel.type == "voice"
          chnl_id = channel.id
      if chnl_id == null
        chnl = "General"
        for channel in dc.servers[guild_id].channels
          if chnl == channel.name && channel.type == "voice"
            chnl_id = channel.id
      dc.joinVoice(chnl_id,guild_id)
    else if command.match(/leave/)
      dc.leaveVoice(guild_id)
  else if msg.match(/^!music\s/)
    if dc.internals.voice.ready
      videoId = msg.split(" ")[1]
      if videoId == "stop"
        dc.stopStream()
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
            raven.captureException(err,{level:'error',request: httpResponse})
            return console.error('Error Occured Fetching Youtube Metadata')
          data = JSON.parse(body)
          if data.items
            if data.items[0]
              console.log(videoId)
              playlistCollection = app.locals.db.collection("playlist")
              playlistCollection.insertOne({videoId: videoId, title: data.items[0].snippet.title, duration: data.items[0].contentDetails.duration, channel_id: channel_id, timestamp: new Date().getTime(), status: 'added'}, (err, result) ->
                if err
                  raven.captureException(err,{level:'error'})
                  dc.sendMessage(channel_id,":warning: A database error occurred adding this track...\nReport sent to sentry, please notify admin of the following error: \`Database insertion error at line 323: "+err.toString()+"\`")
                else
                  dc.sendMessage(channel_id,":notes: Added "+data.items[0].snippet.title)
                  goThroughVideoList(channel_id)
              )
            else
              raven.captureException(new Error("Youtube Error: Googleapis returned video not found for videoId"),{level:'error',extra:{videoId: videoId},request: httpResponse})
              dc.sendMessage(channel_id,":warning: Youtube Error: Googleapis returned video not found for videoId ("+videoId+")")
          else
            raven.captureException(new Error("Youtube Error: Googleapis returned video not found for videoId"),{level:'error',extra:{videoId: videoId},request: httpResponse})
            dc.sendMessage(channel_id,":warning: Youtube Error: Googleapis returned video not found for videoId ("+videoId+")")
        )
      else if videoId == "skip"
        dc.stopStream()
        goThroughVideoList()
      else if videoId == "play"
        goThroughVideoList()
      else if videoId == "list"
        playlistCollection = app.locals.db.collection("playlist")
        playlistCollection.find({status: "added"}).sort({timestamp: 1}).toArray((err, results) ->
          if err
            raven.captureException(err,{level:'error'})
            dc.sendMessage(channel_id,":warning: A database error occurred whilst listing all tracks...\nReport sent to sentry, please notify admin of the following error: \`playlistCollection Error at line 239\`")
          else
            if(results.length > 0)
              songNames = []
              for r in results
                songTitle = r.title
                songNames.push(songTitle)
              dc.sendMessage(channel_id,":headphones: Playlist can be viewed here: https://mb.lolstat.net/")
            else
              dc.sendMessage(channel_id,"No songs are currently in the playlist :grinning:")
        )
      else
        dc.sendMessage(channel_id,"Unknown Voice Command :cry:")
    else
      dc.sendMessage(channel_id,"Hmmmmm, I think you might want to join a Voice Channel first :wink:")
  else if msg.match(/^!sb\spog/)
    if dc.internals.voice.ready
      pogStream = fs.createReadStream(__dirname+'/soundboard/play of the game.mp3')
      dc.playStream(pogStream,{volume: 2.0})
      pogStream.on('end', () ->
        pogStream.close()
        pogStream = null
      )
    else
      dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")
  else if msg.match(/^!sb\sgp/)
    if dc.internals.voice.ready
      pogStream = fs.createReadStream(__dirname+'/soundboard/gp.mp3')
      dc.playStream(pogStream,{volume: 2.0})
    else
      dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")
  else if msg.match(/^!sb\sj3/)
    if dc.internals.voice.ready
      pogStream = fs.createReadStream(__dirname+'/soundboard/justice 3.mp3')
      dc.playStream(pogStream,{volume: 2.0})
    else
      dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")
  else if msg.match(/^!sb\ssb/)
    if dc.internals.voice.ready
      pogStream = fs.createReadStream(__dirname+'/soundboard/speed boost.mp3')
      dc.playStream(pogStream,{volume: 2.0})
    else
      dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")
  else if msg.match(/^!talk\s/)
    console.log("Talk Command Issued")
    request = apiai.textRequest(msg.replace(/^!talk\s/,""))
    request.on('response', (response) ->
      console.log(response)
      dc.sendMessage(channel_id,response.result.fulfillment.speech)
    )
    request.on('error', (error) ->
      raven.captureException(error,{level:'error'})
      console.log(error)
    )
    request.end()
  else if msg.match(/^!/)
    dc.sendMessage(channel_id,"I don't know what you want :cry:")
)

goThroughVideoList = () ->
  if dc.internals.voice.ready
    playlistCollection = app.locals.db.collection("playlist")
    playlistCollection.find({status: "added"}).sort({timestamp: 1}).toArray((err, results) ->
      if results[0]
        videoId = results[0].videoId
        channel_id = results[0].channel_id
        title = results[0].title
        trackId = results[0]._id
        if videoId && !dc.internals.voice.allowPlay
          playlistCollection.updateOne({'_id': trackId},{'$set':{'status':'played'}},() ->
            console.log("Track Status Changed")
          )
          requestUrl = 'http://youtube.com/watch?v=' + videoId
          yStream = youtubeStream(requestUrl,{quality: 'lowest', filter: 'audioonly'})
          yStream.on("error", (e) ->
            raven.captureException(e,{level:'error',tags:{system: 'youtube-stream'}})
            console.log("Error Occured Loading Youtube Video")
          )
          dc.playStream(yStream,{volume: 0.5})
          dur = convertTimestamp(results[0].duration)
          dc.sendMessage(channel_id,":play_pause: Now Playing: "+title+" ("+dur+")")
          console.log("Now Playing: "+title)
    )
  else
    dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")


dc.on("songDone", () ->
  console.log("Song Done")
  goThroughVideoList()
)

dc.on("status", (user_id,status,game,raw_data) ->
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
