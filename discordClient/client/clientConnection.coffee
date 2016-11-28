u = require('../utils.coffee')
utils = new u()
ws = require 'ws'
zlib = require 'zlib'
os = require 'os'
d = require './dispatcher.coffee'

class ClientConnection
  HEARTBEAT_INTERVAL: null
  constructor: (@discordClient) ->
    @gatewayHeartbeat = null
    @discordClient.gatewayWS = null
    @dispatcher = new d(@discordClient, @)
    @discordClient.internals.pings = []
    @discordClient.internals.totalPings = 0
    @discordClient.internals.avgPing = 0

  connect: (gateway) ->
    self = @
    @discordClient.internals.gateway = gateway
    utils.debug("Creating Gateway Connection")
    @discordClient.gatewayWS = new ws(gateway+"/?v=6") #use version 6, cause you can do that :o

    @discordClient.gatewayWS.once('open', () -> self.gatewayOpen())
    @discordClient.gatewayWS.once('close', () -> self.gatewayClose())
    @discordClient.gatewayWS.once('error', (err) -> self.gatewayError(err))
    @discordClient.gatewayWS.on('message', (msg, flags) -> self.gatewayMessage(msg, flags))
    #@discordClient.emit("con")

  gatewayError: (err) ->
    utils.debug("Error Occurred Connecting to Gateway Server: "+err.toString(),"error")

  gatewayClose: () ->
    utils.debug("Connection to Gateway Server CLOSED","warn")

  gatewayOpen: () ->
    utils.debug("Connected to Gateway Server","info")

  sendReadyPayload: () ->
    utils.debug("Using Compression: "+!!zlib.inflateSync)
    idpackage = {
      "op": 2,
      "d": {
        "token": @discordClient.internals.token,
        "properties": {
          "$os": os.platform(),
          "$browser": "discordClient",
          "$device": "discordClient",
          "$referrer": "",
          "$referring_domain": ""
        },
        "compress": !!zlib.inflateSync,
        "large_threshold": 250
      }
    }
    utils.debug("Sending Identity Package")
    @discordClient.gatewayWS.send(JSON.stringify(idpackage))

  helloPackage: (data) ->
    utils.debug("Hello Payload Received")
    @HEARTBEAT_INTERVAL = data.d.heartbeat_interval
    @sendReadyPayload()

  heartbeatACK: (data) ->
    ping = new Date().getTime() - @discordClient.internals.gatewayPing
    @discordClient.internals.pings.push(ping)
    @discordClient.internals.totalPings+=ping
    @discordClient.internals.avgPing = @discordClient.internals.totalPings/@discordClient.internals.pings.length
    utils.debug("Sent Heartbeat with sequence: "+@discordClient.internals.sequence+" ("+ping+"ms - average: "+((Math.round(@discordClient.internals.avgPing*100))/100)+"ms)")

  gatewayMessage: (data, flags) ->
    msg = if flags.binary then JSON.parse(zlib.inflateSync(data).toString()) else JSON.parse(data)
    HELLO = 10
    HEARTBEAT_ACK = 11
    DISPATCH = 0
    switch msg.op
      when HELLO then @helloPackage(msg)
      when HEARTBEAT_ACK then @heartbeatACK(msg)
      when DISPATCH then @dispatcher.parseDispatch(msg)
      else
        utils.debug("Unhandled op: "+msg.op, "warn")

module.exports = ClientConnection
