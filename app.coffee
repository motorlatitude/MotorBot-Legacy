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
    @musicPlayers = {}
    @soundboard = {}
    @yStream = {}
    @voiceConnections = {}
    @init()

  init: () ->
    console.log "Initialising Motorbot"
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
        console.log "Successfully Connected to Database"
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
        client.send(data, (err) ->
          if err then console.log err
        )
      )

  initWebServer: () ->
    console.log "Starting Web Server"
    @webserver = new WebServer(@)
    @webserver.start()
    @webserver.site.listen(3210)

  initPlaylist: () ->
    songQueueCollection = @database.collection("songQueue")
    songQueueCollection.find({status: "playing"}).toArray((err, results) ->
      if err then console.log err
      for r in results
        trackId = r._id
        songQueueCollection.updateOne({'_id': trackId},{'$set':{'status':'played'}},() ->
          console.log("Track Status Changed")
        )
    )

  streamNewTrack: (results) ->
    self = @
    guild_id = "130734377066954752"
    songQueueCollection = @database.collection("songQueue")
    if results[0]
      videoId = results[0].videoId
      title = results[0].title
      trackId = results[0]._id
      playlistId = results[0].playlistId
      song = results[0]
      if videoId
        songQueueCollection.updateOne({'_id': trackId, 'playlistId': playlistId},{'$set':{'status':'playing'}},() ->
          console.log("Track Status Changed")
        )
        requestUrl = 'https://www.youtube.com/watch?v=' + videoId
        self.yStream[guild_id] = youtubeStream(requestUrl,{quality: 'lowest', filter: 'audio'})
        thisystream = self.yStream[guild_id]
        thisystream.on("error", (e) ->
          console.log e
          console.log("Error Occurred Loading Youtube Video")
          #globals.songComplete(true)
        )
        thisystream.on("info", (info, format) ->
          #console.log "INFO"
          #console.log "URL: "+format.url
          #console.log format
          volume = 0.6 #set default, as some videos (recently uploaded maybe?) don't have loudness value
          #stabilise volume to avoid really loud or really quiet playback
          if info.loudness
            volume = (parseFloat(info.loudness)/-27)
            console.log "Setting Volume Based on Video Loudness ("+info.loudness+"): "+volume
          #self.yStream[guild_id] = youtubeStream.downloadFromInfo(info, {quality: 'lowest', filter: 'audio'})
          self.voiceConnections[guild_id].playFromStream(thisystream).then((audioPlayer) ->
            self.musicPlayers[guild_id] = audioPlayer
            self.musicPlayers[guild_id].on('ready', () ->
              setTimeout( () ->
                self.musicPlayers[guild_id].play()
                self.websocket.broadcast(JSON.stringify({type: 'playUpdate', status: 'play'}))
                self.websocket.broadcast(JSON.stringify({type: 'trackUpdate', song: song}))
              ,1000)
              #globals.dc.setStatus(title)
              console.log("Now Playing: "+title)
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
          console.log("Track Status Changed")
          setTimeout(() ->
            self.goThroughSongQueue()
          ,1000)
        )
      else
        self.goThroughSongQueue()
    )

app = new App()