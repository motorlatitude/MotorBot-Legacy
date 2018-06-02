DiscordClient = require './discordClient/discordClient'
WebServer = require './webserver'
motorbotEventHandler = require './motorbotEventHandler'
keys = require './keys.json'
websocketServer = require("ws").Server
MongoClient = require('mongodb').MongoClient
youtubeStream = require 'ytdl-core'
request = require 'request'
stream = require 'stream'

class App

  constructor: () ->
    self = @
    @musicPlayers = {}
    @soundboard = {}
    @say = {}
    @yStream = {}
    @voiceConnections = {}
    @init()
    @log_history = []
    console.log = (d) ->
      self.log_history.push(d)
      process.stdout.write(d + '\n')

  debug: (msg,level = "debug") ->
    if level == "info"
      level = "\x1b[34m[INFO ]\x1b[0m"
    else if level == "error"
      level = "\x1b[31m[ERROR]\x1b[0m"
    else if level == "warn"
      level = "\x1b[5m\x1b[33m[WARN ]\x1b[0m"
    else if level == "notification"
      level = "\x1b[5m\x1b[35m[NOTIF]\x1b[0m"
    else if level == "debug"
      level = "\x1b[2m[DEBUG]"
    d = new Date()
    time = "["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"] "
    console.log(level+time+msg+"\x1b[0m")

  init: () ->
    @debug("Initialising")
    @client = new DiscordClient({token: keys.token})
    new motorbotEventHandler(@, @client)
    @client.connect()
    self = @
    @initDatabase().then(() ->
      self.initWebServer()
      self.initWebSocket()
      self.initPlaylist()
    )

  initDatabase: () ->
    self = @
    new Promise((resolve, reject) ->
      MongoClient.connect('mongodb://localhost:27017/motorbot', (err, db) ->
        if err
          throw new Error("Failed to connect to database, exiting")
        self.database = db
        self.debug("Connected to Database")
        resolve()
      )
    )

  initWebSocket: () ->
    @websocket = websocketServer({port: 3006}) #public port is 443 (wss://wss.lolstat.net) and local 3006 via nginx proxy
    @websocket.on('connection', (ws) ->
      ws.on('message', (message) ->
        #recieved message
      )
    )
    self = @
    @websocket.broadcast = (data) ->
      self.websocket.clients.forEach((client) ->
        if client
          client.send(data, (err) ->
            if err then console.log err
          )
      )

  initWebServer: () ->
    @debug("Starting Web Server")
    @webserver = new WebServer(@)
    @webserver.start()
    @webserver.site.listen(3210)

  initPlaylist: () ->
    self = @
    songQueueCollection = @database.collection("songQueue")
    songQueueCollection.find({status: "playing"}).toArray((err, results) ->
      if err then console.log err
      for r in results
        trackId = r._id
        songQueueCollection.updateOne({'_id': trackId},{'$set':{'status':'played'}},() ->
          self.debug("Track Status Changed")
        )
    )

  streamNewTrack: (results) ->
    self = @
    guild_id = "130734377066954752"
    songQueueCollection = @database.collection("songQueue")
    tracksCollection = @database.collection("tracks")
    playlistsCollection = @database.collection("playlists")
    if results[0]
      videoId = results[0].video_id
      title = results[0].title
      trackId = results[0]._id
      song_id = results[0].id
      playlistId = results[0].playlistId
      song = results[0]
      if videoId
        songQueueCollection.updateOne({'_id': trackId, 'playlistId': playlistId},{'$set':{'status':'playing'}},(err, result) ->
          if !err then self.debug("Track Status Changed")
        )
        tracksCollection.updateOne({'id': song_id},{'$inc':{'play_count':1}},(err, result) ->
          if !err then self.debug("Tracks Play Count increased")
        )
        playlistsCollection.updateOne({'id': playlistId, "songs.id": song_id},{'$inc':{'songs.$.play_count':1}, '$set':{'songs.$.last_played': new Date().getTime()}},(err, result) ->
          if !err then self.debug("Playlist Play Count increased")
        )
        requestUrl = 'https://www.youtube.com/watch?v=' + videoId
        self.yStream[guild_id] = youtubeStream(requestUrl,{quality: 'highest', filter: 'audio'})
        thisystream = self.yStream[guild_id]
        thisystream.on("error", (e) ->
          console.log e
          self.debug("Error Occurred Loading Youtube Video")
          self.nextSong()
        )
        thisystream.on("info", (info, format) ->
          #console.log "INFO"
          #console.log "URL: "+format.url
          #console.log format
          volume = 0.6 #set default, as some videos (recently uploaded maybe?) don't have loudness value
          #stabilise volume to avoid really loud or really quiet playback
          if info.loudness
            volume = (parseFloat(info.loudness)/-27)
            self.debug "Setting Volume Based on Video Loudness ("+info.loudness+"): "+volume
          self.voiceConnections[guild_id].playFromStream(thisystream).then((audioPlayer) ->
            self.musicPlayers[guild_id] = audioPlayer
            self.musicPlayers[guild_id].on('ready', () ->
              self.musicPlayers[guild_id].setVolume(volume)
              self.musicPlayers[guild_id].play()
              self.musicPlayers[guild_id].playing = true
              self.websocket.broadcast(JSON.stringify({type: 'playUpdate', status: 'play'}))
              self.websocket.broadcast(JSON.stringify({type: 'trackUpdate', song: song}))
              self.client.setStatus(title)
              self.debug("Now Playing: "+title)
            )
            startTime = 0
            self.musicPlayers[guild_id].on("streamTime", (time) ->
              if time < 1000
                startTime = 0
              if time >= startTime+1000
                startTime += 1000
                self.websocket.broadcast(JSON.stringify({type: 'songTime', time: time}))
            )
            #musicPlayers[guild_id].pause()
            self.musicPlayers[guild_id].on("streamDone", () ->
              self.musicPlayers[guild_id] = undefined
              self.nextSong()
            )
          )
        )

  goThroughSongQueue: () ->
    self = @
    songQueueCollection = @database.collection("songQueue")
    songQueueCollection.find({status: "queued"}).toArray((err, results) ->
      if err then console.log err
      if results[0]
        self.streamNewTrack(results)
      else
        #no songs in queue, go to nextSong
        ###if globals.randomPlayback
          songQueueCollection.find({status: "added"}).sort({randId: 1}).toArray((err, results) ->
            if err then console.log err
            streamNewTrack(results)
          )
        else###
        songQueueCollection.find({status: "added"}).toArray((err, results) ->
          if err then console.log err
          self.streamNewTrack(results)
        )
    )

  nextSong: () ->
    self = @
    songQueueCollection = @database.collection("songQueue")
    songQueueCollection.find({status: "playing"}).sort({timestamp: 1}).toArray((err, results) ->
      if err then console.log err
      if results[0]
        trackId = results[0]._id
        playlistId = results[0].playlistId
        songQueueCollection.updateOne({'_id': trackId, 'playlistId': playlistId},{'$set':{'status':'played'}},() ->
          self.debug("Track Status Changed")
          setTimeout(() ->
            self.goThroughSongQueue()
          ,1000)
        )
      else
        self.goThroughSongQueue()
    )

  skipSong: () ->
    if @musicPlayers["130734377066954752"]
      @musicPlayers["130734377066954752"].stop()
    else
      @nextSong()

app = new App()