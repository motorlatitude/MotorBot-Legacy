EventEmitter = require('events').EventEmitter

Debug = require './debug/Debug'

DiscordClient = require 'discord-coffee'

MotorBotEventHandler = require './MotorBotEventHandler.coffee'
MongoDatabase = require './MongoDatabase.coffee'
MotorBotWebServer = require './WebServer.coffee'
MotorBotWebSocket = require './WebSocket.coffee'
MotorBotMusic = require './MotorBotMusic.coffee'
MotorBotSoundboard = require './MotorBotSoundboard.coffee'
MotorBotTwitchStreamNotifier = require './MotorBotTwitchStreamNotifier.coffee'

keys = require './../keys.json'
pjon = require './../package.json'

class Main extends EventEmitter

  constructor: () ->
    super()

    @Logger = new Debug("verbose")
    @Logger.write("Initialising")
    @Client = undefined
    @Database = undefined
    @WebServer = undefined
    @WebSocket = undefined
    @Music = undefined
    @motorbotEventHandler = undefined
    @soundboard = undefined

    @VoiceStates = {}
    @UserStatus = {}


  run: () ->
    @Logger.write("Starting MotorBot "+pjon.version, "info")
    @CreateDiscordClient()
    self = @
    @CreateMongoDatabaseConnection().then((db) ->
      self.Database = db
      self.CreateWebServer() #handles web interface
      self.CreateWebSocket() #handles web interface
      self.CreateMotorBotMusic() #handles playback from interface to node-discord
      self.CreateMotorBotSoundboard() #handles sound effects from discord chat and handles the playback from interface to node-discord
      self.CreateMotorBotTwitchNotifier() #handles subscribing to twitch webhook service
      self.emit("MotorBotReady", {}) #we have set everything up, lets say we're ready
    ).catch((err) ->
      console.log err
      throw new Error("Failed to Connect to Database Or Failed to Initialise a MotorBot Component")
    )

  CreateMotorBotTwitchNotifier: () ->
    tn = new MotorBotTwitchStreamNotifier(@, @Logger, keys.twitch)
    tn.RegisterListener(22032158) #motorlatitude
    tn.RegisterListener(26752266) #mutme
    tn.RegisterListener(26538483) #sips_
    tn.RegisterListener(22510310) #GDQ
    tn.RegisterListener(36029255) #RiotGames

  CreateMotorBotSoundboard: () ->
    @soundboard = new MotorBotSoundboard(@, @Logger)

  CreateDiscordClient: () ->
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