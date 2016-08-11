EventEmitter = require('events').EventEmitter
req = require 'request'
pjson = require '../package.json'
u = require('./utils.coffee')
utils = new u()

clientConnection = require './client/clientConnection.coffee'

class DiscordClient extends EventEmitter

  constructor: (@options) ->
    if !@options.token then throw new Error("No Token Provided")

  getGateway: () ->
    self = @
    utils.debug("Retrieving Discord Gateway Server")
    req.get({url: "https://discordapp.com/api/gateway", json: true, time: true}, (err, res, data) ->
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
    @internals.connected = false

    cc = new clientConnection(@)
    cc.connect(gateway) #connect to discord gateway server

  #PUBLIC METHODS
  connect: () ->
    utils.debug("Starting MotorBot "+pjson.version,"info")
    @internals = {}
    @internals.servers = {}
    @internals.voice = {}
    @internals.sequence = 0
    @getGateway()
  
  joinVoiceChannel: (channel_id) ->
    #get server for channel_id
    channelId = null
    guildId = null
    for serverId, server of @internals.servers
      for channel in server.channels
        if channel.id == channel_id && channel.type = 2
          channelId = channel.id
          guildId = serverId
          break
    if channelId == null || guildId == null
      return utils.debug("Channel wasn't found or of incorrect type", "warn")
    joinVoicePackage = {
      "op": 4,
      "d": {
        "guild_id": guildId,
        "channel_id": channelId,
        "self_mute": false,
        "self_deaf": false
      }
    }
    @gatewayWS.send(JSON.stringify(joinVoicePackage))
  
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
