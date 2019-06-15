WebSocketServer = require("ws").Server
cuid = require 'cuid'

class WebSocket

  constructor: (@app, @Logger) ->
    self = @
    @wss = new WebSocketServer({port: 3006})
    @wss.ConnectedClients = []
    @wss.on("connection", (ws) ->
      self.NewConnection(ws)
    )
    @wss.broadcastByGuildID = (data, guild_id) ->
      if guild_id
        self.wss.ConnectedClients.forEach((client) ->
          if client
            if client.guild == guild_id
              client.ws.send(data, (err) ->
                if err then console.log err
              )
        )

    @wss.broadcast = (data, user_id) ->
      if user_id
        self.wss.ConnectedClients.forEach((client) ->
          if client
            if client.user_id == user_id
              client.ws.send(data, (err) ->
                if err then console.log err
              )
        )
      else
        self.wss.clients.forEach((client) ->
          if client
            client.send(data, (err) ->
              if err then console.log err
            )
        )
    return @wss

  NewConnection: (ws) ->
    @Logger.write("WebSocket Connection")
    session = Buffer(new Date().getTime() + cuid()).toString("base64")
    @Logger.write("A New WebSocket Connection Has Been Registered: "+session,"info")

    self = @

    ws.on("close", (e) ->
      self.Logger.write("[WEBSOCKET][/ ][WSS.MOTORBOT.IO]: SOCKET CLOSED","warn")
      self.wss.ConnectedClients.forEach((client) ->
        if client
          if client.session == session
            self.wss.ConnectedClients.splice(self.wss.ConnectedClients.indexOf(client),1)
      )
    )

    ws.on("message", (message) ->
      self.Logger.write("[WEBSOCKET][<=][WSS.MOTORBOT.IO]: "+message)
      self.HandleMessage(ws, session, message)
    )

  HandleMessage: (ws, session, message) ->
    self = @
    msg = {}
    try
      msg = JSON.parse(message);
    catch e
      console.log message
      console.log e
    switch msg.op
      when 0
        ws.send(JSON.stringify({op: 1, type:"HEARTBEAT_ACK", d:{}}), (err) ->
          if err then console.log err
        )
      when 2
        self.wss.ConnectedClients.push({
          id: new Date().getTime() + msg.d.user_id,
          user_id: msg.d.user_id,
          ws: ws,
          session: session,
          t: new Date().getTime()
        })
        welcome_obj = {
          guilds: {},
          session: session
        }
        if self.app.Client.guilds
          guilds = self.app.Client.guilds
          for key, guild of guilds
            if self.app.Client.voiceConnections[guild.id]
              guilds[key].connected_voice_channel = self.app.Client.voiceConnections[guild.id].channel_name || undefined
            else
              guilds[key].connected_voice_channel = undefined
          welcome_obj.guilds = guilds #this should be changed to be user specific and only show the ones motorbot is part of
        ws.send(JSON.stringify({op: 3, type:"WELCOME", d:welcome_obj}, (key, value) ->
          if key == "client" then return undefined else return value
        ), (err) ->
          if err then console.log err
        )
      when 8
        #PLAYER_STATE
        cc = undefined
        self.wss.ConnectedClients.forEach((client) ->
          if client
            if client.session == msg.d.session
              cc = client
              if cc
                if cc.guild
                  if self.app.Music.musicPlayers[cc.guild]
                    playlistId = self.app.Music.musicPlayers[cc.guild].playlist_id
                    songId = self.app.Music.musicPlayers[cc.guild].song_id
                    player_state = self.app.Music.musicPlayers[cc.guild].player_state
                    self.Logger.write("PLAYER_STATE requested")
                    if self.app.Music.musicPlayers[cc.guild].playing
                      ws.send(JSON.stringify({type: 'PLAYER_UPDATE', op: 7, d: {event_type: 'PLAY', player_state: player_state, playlist_id: playlistId, song_id: songId}}))
                    else
                      ws.send(JSON.stringify({type: 'PLAYER_UPDATE', op: 7, d: {event_type: 'PAUSE', player_state: player_state, playlist_id: playlistId, song_id: songId}}))
                  else
                    ws.send(JSON.stringify({type: 'PLAYER_UPDATE', op: 7, d: {event_type: 'STOP', player_state: player_state, playlist_id: undefined, song_id: undefined}}))
                else
                  self.Logger.write("PLAYER_STATE requested without registering WebSocket connection first", "warn")
              else
                self.Logger.write("PLAYER_STATE requested without registering WebSocket connection first", "warn")
        )
      when 10
        #connect to a guild
        self.wss.ConnectedClients.forEach((client, i) ->
          if client
            if client.session == msg.d.session
              self.wss.ConnectedClients[i].guild = msg.d.id
              self.Logger.write("Updating Connected Clients")
              guild_state_obj = {
                playing: {},
                guild: self.app.Client.guilds[msg.d.id],
                channel: undefined,
                session: session
              }
              songQueueCollection = self.app.Database.collection("songQueue")
              songQueueCollection.find({status:'playing', guild: msg.d.id}).toArray((err, results) ->
                if err then console.log err
                if results[0]
                  results[0][msg.d.id] = false
                  if self.app.Music.musicPlayers #weird
                    if self.app.Music.musicPlayers[msg.d.id]
                      results[0]["currently_playing"] = self.app.Music.musicPlayers[msg.d.id].playing
                      results[0]["start_time"] = self.app.Music.musicPlayers[msg.d.id].start_time
                      results[0]["position"] = self.app.Music.musicPlayers[msg.d.id].seekPosition
                      results[0]["playlist_id"] = self.app.Music.musicPlayers[msg.d.id].playlist_id
                      results[0]["player_state"] = self.app.Music.musicPlayers[msg.d.id].player_state
                  guild_state_obj.playing = results[0]
                else
                  guild_state_obj.playing = {currently_playing: false}

                if self.app.Client.voiceConnections[msg.d.id] then guild_state_obj.channel = self.app.Client.voiceConnections[msg.d.id].channel_name
                ws.send(JSON.stringify({op: 11, type:"GUILD_STATE", d:guild_state_obj}, (key, value) ->
                  if key == "client" then return undefined else return value
                ), (err) ->
                  if err then console.log err
                )
              )
        )

module.exports = WebSocket