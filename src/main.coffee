EventEmitter = require('events').EventEmitter

Debug = require './debug/Debug'

DiscordClient = require 'node-discord'

MotorBotEventHandler = require './MotorBotEventHandler.coffee'
MongoDatabase = require './MongoDatabase.coffee'
MotorBotWebServer = require './WebServer.coffee'
MotorBotWebSocket = require './WebSocket.coffee'
MotorBotMusic = require './MotorBotMusic.coffee'

keys = require './../keys.json'

class Main extends EventEmitter

  constructor: () ->
    super()

    @Logger = new Debug("verbose")
    @Client = undefined
    @Database = undefined
    @WebServer = undefined
    @WebSocket = undefined
    @Music = undefined
    @motorbotEventHandler = undefined

    @VoiceStates = {}
    @UserStatus = {}


  run: () ->
    @CreateDiscordClient()
    self = @
    @CreateMongoDatabaseConnection().then((db) ->
      self.Database = db
      self.CreateWebServer()
      self.CreateWebSocket()
      self.CreateMotorBotMusic()
      self.emit("MotorBotReady", {})
    ).catch((err) ->
      console.log err
      throw new Error("Failed to Connect to database")
    )

  CreateDiscordClient: () ->
    @Logger.write("Initialising")
    @Client = new DiscordClient({token: keys.token, debug: "verbose"})
    @RegisterEventListener(@Client)
    @Client.connect()

  CreateMongoDatabaseConnection: () ->
    self = @
    return new Promise((resolve, reject) ->
      db = new MongoDatabase(self.Logger);
      db.connect().then((d) ->
        resolve(d)
      ).catch((err) ->
        reject(err)
      )
    )

  CreateWebServer: () ->
    self = @
    @Logger.write("Starting Web Server")
    @WebServer = new MotorBotWebServer(@, @Logger)
    @WebServer.start()
    @WebServer.site.listen(3210, "localhost", () ->
      self.Logger.write("Web Server Started and Listening on 3210","info")
    ).on("error", (err) ->
      self.Logger.write(err,"error")
    )

  CreateWebSocket: () ->
    @Logger.write("Starting WebSocket")
    @WebSocket = new MotorBotWebSocket(@, @Logger)

  CreateMotorBotMusic: () ->
    @Music = new MotorBotMusic(@, @Logger)
    self = @
    @Music.InitialisePlaylist().then(() ->

    ).catch((err) ->
      self.Logger.write(err, "error")
    )

  RegisterEventListener: (client) ->
    @motorbotEventHandler = new MotorBotEventHandler(@, @Logger)
    @motorbotEventHandler.RegisterEventListener(client)

  ConnectedGuild: (user_id) ->
    self = @
    guild_id = undefined
    if self.WebSocket.ConnectedClients
      for client in self.WebSocket.ConnectedClients
        if client
          if client.user_id == user_id
            guild_id = client.guild
            if !guild_id then self.Logger("This user isn't connected to a guild currently?")
            return guild_id

module.exports = Main