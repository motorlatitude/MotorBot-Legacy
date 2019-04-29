DiscordClient = require './discordClient/discordClient'
WebServer = require './webserver'
motorbotEventHandler = require './motorbotEventHandler'
keys = require './keys.json'
websocketServer = require("ws").Server
#SocketCluster = require('socketcluster');
stream = require 'stream'
http2 = require 'http2'
MongoClient = require('mongodb').MongoClient
youtubeStream = require 'ytdl-core'
request = require 'request'
fs = require 'fs'
path = require 'path'
uid = require('rand-token').uid;

class App

  constructor: () ->
    self = @
    @musicPlayers = {}
    @soundboard = {}
    @say = {}
    @yStream = {}
    ###if cluster.isMaster
      cluster.on('online', (worker) ->
        console.log('Worker ' + worker.process.pid + ' is online')
      )

      cluster.on('exit', (worker, code, signal) ->
        console.log('Worker ' + worker.process.pid + ' died with code: ' + code + ', and signal: ' + signal)
        console.log('Starting a new worker')
        cluster.fork()
      )

      for i in [0..2]
        cluster.fork()
    else###
    @init()

  debug: (msg,level = "debug") ->
    if (process.env.NODE_ENV != 'test')
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
    self = @
    @debug("Initialising WebSocket Connection")
    @websocket = websocketServer({port: 3006}) #public port is 443 (wss://wss.lolstat.net) and local 3006 via nginx proxy
    @websocket.connectedClients = []
    @websocket.on('connection', (ws) ->
      self.debug("WebSocket Connection")
      session = Buffer(new Date().getTime() + uid(32)).toString("base64")
      self.debug("A New WebSocket Connection Has Been Registered: "+session,"info");

      ws.on("close", (e) ->
        console.log "SOCKET CLOSED"
        self.websocket.connectedClients.forEach((client) ->
          if client
            if client.session == session
              self.websocket.connectedClients.splice(self.websocket.connectedClients.indexOf(client),1)
        )
      )
      ws.on('message', (message) ->
        #recieved message
        self.debug("[WEBSOCKET][INCOMING]: "+message)
        msg = JSON.parse(message);
        switch msg.op
          when 0
            ws.send(JSON.stringify({op: 1, type:"HEARTBEAT_ACK", d:{}}), (err) ->
              if err then console.log err
            )
          when 2
            self.websocket.connectedClients.push({
              id: new Date().getTime() + msg.d.user_id,
              user_id: msg.d.user_id,
              ws: ws,
              session: session
            })
            welcome_obj = {
              guilds: {},
              session: session
            }
            if self.client.guilds then welcome_obj.guilds = self.client.guilds #this should be changed to be user specific and only show the ones motorbot is part of
            ws.send(JSON.stringify({op: 3, type:"WELCOME", d:welcome_obj}, (key, value) ->
              if key == "client" then return undefined else return value
            ), (err) ->
              if err then console.log err
            )
          when 8
            #PLAYER_STATE
            cc = undefined
            self.websocket.connectedClients.forEach((client) ->
              if client
                if client.session == msg.d.session
                  cc = client
                  if cc
                    if cc.guild
                      if self.musicPlayers[cc.guild]
                        playlistId = self.musicPlayers[cc.guild].playlist_id
                        songId = self.musicPlayers[cc.guild].song_id
                        player_state = self.musicPlayers[cc.guild].player_state
                        self.debug("PLAYER_STATE requested")
                        if self.musicPlayers[cc.guild].playing
                          ws.send(JSON.stringify({type: 'PLAYER_UPDATE', op: 7, d: {event_type: 'PLAY', player_state: player_state, playlist_id: playlistId, song_id: songId}}))
                        else
                          ws.send(JSON.stringify({type: 'PLAYER_UPDATE', op: 7, d: {event_type: 'PAUSE', player_state: player_state, playlist_id: playlistId, song_id: songId}}))
                      else
                        ws.send(JSON.stringify({type: 'PLAYER_UPDATE', op: 7, d: {event_type: 'STOP', player_state: player_state, playlist_id: undefined, song_id: undefined}}))
                    else
                      self.debug("PLAYER_STATE requested without registering WebSocket connection first", "warn")
                  else
                    self.debug("PLAYER_STATE requested without registering WebSocket connection first", "warn")
            )
          when 10
            #connect to a guild
            self.websocket.connectedClients.forEach((client, i) ->
              if client
                if client.session == msg.d.session
                  self.websocket.connectedClients[i].guild = msg.d.id
                  self.debug("Updating Connected Clients")
                  guild_state_obj = {
                    playing: {},
                    channel: undefined,
                    session: session
                  }
                  songQueueCollection = self.database.collection("songQueue")
                  songQueueCollection.find({status:'playing', guild: msg.d.id}).toArray((err, results) ->
                    if err then console.log err
                    if results[0]
                      results[0][msg.d.id] = false
                      if self.musicPlayers #weird
                        if self.musicPlayers[msg.d.id]
                          results[0]["currently_playing"] = self.musicPlayers[msg.d.id].playing
                          results[0]["start_time"] = self.musicPlayers[msg.d.id].start_time
                          results[0]["position"] = self.musicPlayers[msg.d.id].seekPosition
                          results[0]["playlist_id"] = self.musicPlayers[msg.d.id].playlist_id
                          results[0]["player_state"] = self.musicPlayers[msg.d.id].player_state
                      guild_state_obj.playing = results[0]
                    else
                      guild_state_obj.playing = {currently_playing: false}

                    if self.client.voiceConnections[msg.d.id] then guild_state_obj.channel = self.client.voiceConnections[msg.d.id].channel_name
                    ws.send(JSON.stringify({op: 11, type:"GUILD_STATE", d:guild_state_obj}, (key, value) ->
                      if key == "client" then return undefined else return value
                    ), (err) ->
                      if err then console.log err
                    )
                  )
            )
        )
      )
    @websocket.broadcastByGuildID = (data, guild_id) ->
      if guild_id
        self.websocket.connectedClients.forEach((client) ->
          if client
            if client.guild == guild_id
              client.ws.send(data, (err) ->
                if err then console.log err
              )
        )

    @websocket.broadcast = (data, user_id) ->
      if user_id
        self.websocket.connectedClients.forEach((client) ->
          if client
            if client.user_id == user_id
              client.ws.send(data, (err) ->
                if err then console.log err
              )
        )
      else
        self.websocket.clients.forEach((client) ->
          if client
            client.send(data, (err) ->
              if err then console.log err
            )
        )

  initWebServer: () ->
    self = @
    @debug("Starting Web Server")
    @webserver = new WebServer(@)
    @webserver.start()
    @webserver.site.listen(3210, "localhost", () ->
      self.debug("Web Server Started and Listening on 3210","info")
    ).on("error", (err) ->
      console.log err
    )

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

  streamNewTrack: (results, guild_id) ->
    self = @
    #guild_id = "130734377066954752"
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
        songQueueCollection.updateOne({'_id': trackId, 'playlistId': playlistId, guild: guild_id},{'$set':{'status':'playing'}},(err, result) ->
          if !err then self.debug("Track Status Changed")
        )
        tracksCollection.updateOne({'id': song_id},{'$inc':{'play_count':1}},(err, result) ->
          if !err then self.debug("Tracks Play Count increased")
        )
        playlistsCollection.updateOne({'id': playlistId, "songs.id": song_id},{'$inc':{'songs.$.play_count':1}, '$set':{'songs.$.last_played': new Date().getTime()}},(err, result) ->
          if !err then self.debug("Playlist Play Count increased")
        )
        requestUrl = 'https://www.youtube.com/watch?v=' + videoId
        youtubeStream.getInfo(requestUrl, (err, info) ->
          volume = 0.5 #set default, as some videos (recently uploaded maybe?) don't have loudness value
          #stabilise volume to avoid really loud or really quiet playback
          if info
            if info.loudness
              volume = (parseFloat(info.loudness)/-40)
              self.debug "Setting Volume Based on Video Loudness ("+info.loudness+"): "+volume
            self.yStream[guild_id] = youtubeStream.downloadFromInfo(info,{quality: 'highest', filter: 'audioonly'})
            thisystream = self.yStream[guild_id]
            thisystream.on("error", (e) ->
              console.log "e: "+e.toString()
              self.debug("Error Occurred Loading Youtube Video")
              self.websocket.broadcast(JSON.stringify({type: 'YOUTUBE_ERROR', op:6, d: {error: e.toString()}}))
              self.nextSong(guild_id)
            )
            if self.client.voiceConnections[guild_id]
              console.log self.client.voiceConnections
              self.client.voiceConnections[guild_id].playFromStream(thisystream).then((audioPlayer) ->
                self.musicPlayers[guild_id] = audioPlayer
                self.musicPlayers[guild_id].on('ready', () ->
                  self.musicPlayers[guild_id].setVolume(volume)
                  self.musicPlayers[guild_id].play()
                  self.musicPlayers[guild_id].playing = true
                  self.musicPlayers[guild_id].start_time = new Date().getTime()
                  self.musicPlayers[guild_id].playlist_id = playlistId
                  self.musicPlayers[guild_id].song_id = song_id
                  results.shift()
                  playerState = {
                    isPaused: false,
                    isPlaying: true,
                    isStopped: false,
                    restrictions: {},
                    next_tracks: results,
                    previous_tracks: [],
                    current_song: song,
                    seekPosition: 0
                  }
                  if !results[1]
                    playerState.restrictions["skip"] = true
                  songQueueCollection.find({status: "played", guild: guild_id}).sort({sortId: -1}).toArray((err, results) ->
                    if err then console.log err
                    if !results[0]
                      playerState.restrictions["back"] = true
                    else
                      playerState.previous_tracks = results
                    self.musicPlayers[guild_id].player_state = playerState
                    self.websocket.broadcast(JSON.stringify({type: 'PLAYER_UPDATE', op: 7, d: {event_type: 'PLAY', player_state: playerState, playlist_id: playlistId, song_id: song_id}}))
                  )
                  self.websocket.broadcast(JSON.stringify({type: 'TRACK_UPDATE', op: 5, d: {event_type: "CHANGE", event_data: song, start_time: new Date().getTime()}}))
                  self.client.setStatus(title)
                  self.debug("Now Playing: "+title)
                )
                self.musicPlayers[guild_id].on("progress", (seconds) ->
                  self.websocket.broadcast(JSON.stringify({type: 'TRACK_DOWNLOAD', op: 10, d: {event_type: "UPDATE", event_data: {download_position: seconds}}}))
                )
                self.musicPlayers[guild_id].on("streamDone", () ->
                  delete self.musicPlayers[guild_id]
                  self.client.setStatus("") # reset to blank
                  self.nextSong(guild_id)
                )
              ).catch((err) ->
                console.log "ERROR OCCURRED CREATING AUDIO PLAYER"
                console.log err
              )
            else
              console.log "Somin aint right here, no voice connection exists for this guild"
          else
            self.debug("Error Occurred Loading Youtube Video")
            self.websocket.broadcast(JSON.stringify({type: 'YOUTUBE_ERROR', op:6, d: {error: "We couldn't retrieve information for this youtube video"}}))
            self.nextSong(guild_id)
        )

  goThroughSongQueue: (guild_id) ->
    self = @
    songQueueCollection = @database.collection("songQueue")
    songQueueCollection.find({status: "queued", guild: guild_id}).sort({sortId: 1}).toArray((err, results) ->
      if err then console.log err
      if results[0]
        self.streamNewTrack(results, guild_id)
      else
        #no songs in queue, go to nextSong
        ###if globals.randomPlayback
          songQueueCollection.find({status: "added"}).sort({randId: 1}).toArray((err, results) ->
            if err then console.log err
            streamNewTrack(results)
          )
        else###
        songQueueCollection.find({status: "added", guild: guild_id}).sort({sortId: 1}).toArray((err, results) ->
          if err then console.log err
          self.streamNewTrack(results, guild_id)
        )
    )

  nextSong: (guild_id) ->
    self = @
    songQueueCollection = @database.collection("songQueue")
    songQueueCollection.find({status: "playing", guild: guild_id}).sort({sortId: 1}).toArray((err, results) ->
      if err then console.log err
      if results[0]
        trackId = results[0]._id
        playlistId = results[0].playlistId
        songQueueCollection.updateOne({'_id': trackId, 'playlistId': playlistId, guild: guild_id},{'$set':{'status':'played'}},() ->
          self.debug("Track Status Changed")
          setTimeout(() ->
            self.goThroughSongQueue(guild_id)
          ,1000)
        )
      else
        self.goThroughSongQueue(guild_id)
    )

  lastSong: (guild_id) ->
      self = @
      songQueueCollection = @database.collection("songQueue")
      songQueueCollection.find({status: "playing", guild: guild_id}).sort({sortId: 1}).toArray((err, results) ->
        if err then console.log err
        if results[0]
          trackId = results[0]._id
          playlistId = results[0].playlistId
          songQueueCollection.updateOne({'_id': trackId, 'playlistId': playlistId, guild: guild_id},{'$set':{'status':'added'}},() ->
            self.debug("Track Status Changed");
            songQueueCollection.find({status: "played", guild: guild_id}).sort({sortId: -1}).toArray((err, results) ->
              if err then console.log err
              if results[0]
                trackId = results[0]._id
                playlistId = results[0].playlistId
                songQueueCollection.updateOne({'_id': trackId, 'playlistId': playlistId},{'$set':{'status':'added'}},() ->
                  self.debug("Track Status Changed");
                  setTimeout(() ->
                    self.goThroughSongQueue(guild_id)
                  ,1000)
                )
              else
                self.debug("No Songs To Go Back To");
            )
          )
        else
          self.goThroughSongQueue(guild_id)
      )

  connectedGuild: (user_id) ->
    self = @
    guild_id = undefined
    for client in self.websocket.connectedClients
      if client
        if client.user_id == user_id
          guild_id = client.guild
          if !guild_id then self.debug("This user isn't connected to a guild currently?")
          return guild_id

  skipSong: (guild_id) ->
    if @musicPlayers[guild_id]
      @musicPlayers[guild_id].stop()
    else
      @nextSong(guild_id)

  backSong: (guild_id) ->
    @lastSong(guild_id)


app = new App()
