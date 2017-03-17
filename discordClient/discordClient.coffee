EventEmitter = require('events').EventEmitter
Constants = require './constants.coffee'
req = require 'request'
pjson = require '../package.json'
u = require('./utils.coffee')
utils = new u()
DiscordManager = require './rest/DiscordManager'

clientConnection = require './client/clientConnection.coffee'

class DiscordClient extends EventEmitter

  constructor: (@options) ->
    if !@options.token then throw new Error("No Token Provided")
    @rest = new DiscordManager(@)

  getGateway: () ->
    self = @
    utils.debug("Retrieving Discord Gateway Server")
    req.get({url: Constants.api.host+"/gateway", json: true, time: true}, (err, res, data) ->
      if res.statusCode != 200 || err
        utils.debug("Error Occurred Obtaining Gateway Server: "+res.statusCode+" "+res.statusMessage,"error")
        return @emit("disconnect")
      ping = res.elapsedTime
      utils.debug("Gateway Server: "+data.url+" ("+ping+"ms)")
      self.establishGatewayConnection(data.url)
    )

  establishGatewayConnection: (gateway) ->
    self = @
    @internals.gateway = gateway
    @internals.token = @options.token
    @connected = false

    cc = new clientConnection(@)
    cc.connect(gateway) #connect to discord gateway server

  #PUBLIC METHODS
  connect: () ->
    utils.debug("Starting MotorBot "+pjson.version,"info")
    @internals = {}
    @internals.voice = {}
    @internals.sequence = 0
    @channels = {}
    @guilds = {}
    @voiceHandlers = {}
    @voiceConnections = {}
    @getGateway()

  setStatus: (status) ->
    dataMsg = {
      "op": 3,
      "d" :{
        "idle_since": null,
        "game": {
          "name": status
        }
      }
    }
    if @gatewayWS.readyState == @gatewayWS.OPEN
      @gatewayWS.send(JSON.stringify(dataMsg))
      utils.debug("Status Succesfully Set to \""+status+"\"","info")
  
  leaveVoiceChannel: (server) ->
    leaveVoicePackage = {
      "op": 4,
      "d": {
        "guild_id": server,
        "channel_id": null,
        "self_mute": false,
        "self_deaf": false
      }
    }
    @gatewayWS.send(JSON.stringify(leaveVoicePackage))

module.exports = DiscordClient
