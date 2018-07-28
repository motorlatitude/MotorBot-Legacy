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
    @discordClient.internals.resuming = false
    @discordClient.internals.connection_retry_count = 0

  connect: (@gateway) ->
    self = @
    @discordClient.internals.gateway = @gateway
    utils.debug("Creating Gateway Connection")
    @discordClient.gatewayWS = new ws(self.gateway+"/?v=6") #use version 6, cause you can do that :o

    @discordClient.gatewayWS.once('open', () -> self.gatewayOpen())
    @discordClient.gatewayWS.once('close', () -> self.gatewayClose())
    @discordClient.gatewayWS.once('error', (err) -> self.gatewayError(err))
    @discordClient.gatewayWS.on('message', (msg, flags) -> self.gatewayMessage(msg, flags))
    #@discordClient.emit("con")

  gatewayError: (err) ->
    utils.debug("Error Occurred Connecting to Gateway Server: "+err.toString(),"error")

  gatewayClose: () ->
    utils.debug("Connection to Gateway Server CLOSED","warn")
    utils.debug("Attempting To Reacquire Connection to Gateway Server","info")
    clearInterval(@gatewayHeartbeat)
    @sendResumePayload()

  gatewayOpen: () ->
    utils.debug("Connected to Gateway Server","info")
    if @discordClient.internals.resuming
      resumePackage = {
        "op": 6,
        "d": {
          "token": @discordClient.internals.token,
          "session_id": @discordClient.internals.session_id,
          "seq": @discordClient.internals.sequence
        }
      }
      utils.debug("Sending Resume Package")
      console.log resumePackage
      @discordClient.gatewayWS.send(JSON.stringify(resumePackage))

  sendResumePayload: () ->
    if @discordClient.internals.connection_retry_count < 5
      @discordClient.internals.resuming = true
      @dispatcher.connected = false
      @discordClient.internals.connection_retry_count++
      self = @
      setTimeout(() ->
        self.connect(self.gateway)
      , 1000)
    else
      utils.debug("Failed to Resume Connection: Retry Limit Exceeded","error")
      utils.debug("Terminating","warn")

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
    if @discordClient.internals.resuming
      utils.debug("Ignoring Hello, attempting resume")
      @HEARTBEAT_INTERVAL = data.d.heartbeat_interval
    else
      @HEARTBEAT_INTERVAL = data.d.heartbeat_interval
      @sendReadyPayload()
    self = @
    # Setup gateway heartbeat
    utils.debug("Starting Heartbeat: "+@HEARTBEAT_INTERVAL)
    @gatewayHeartbeat = setInterval(() ->
      hbPackage = {
        "op": 1
        "d": self.discordClient.internals.sequence
      }
      self.discordClient.internals.gatewayPing = new Date().getTime()
      if self.discordClient.gatewayWS
        self.discordClient.gatewayWS.send(JSON.stringify(hbPackage))
      else
        utils.debug("Gateway WebSocket Closed?","error")
    ,@HEARTBEAT_INTERVAL)

  heartbeatACK: (data) ->
    ping = new Date().getTime() - @discordClient.internals.gatewayPing
    @discordClient.internals.pings.push(ping)
    @discordClient.internals.totalPings+=ping
    @discordClient.internals.avgPing = @discordClient.internals.totalPings/@discordClient.internals.pings.length
    utils.debug("Sent Heartbeat with sequence: "+@discordClient.internals.sequence+" ("+ping+"ms - average: "+((Math.round(@discordClient.internals.avgPing*100))/100)+"ms)")

  handleInvalidSession: (data) ->
    self = @
    if @discordClient.internals.resuming
      utils.debug("Resuming Failed: INVALID_SESSION","error")
      utils.debug("Attempting Full Reconnect")
      clearInterval(@gatewayHeartbeat)
      @discordClient.internals.resuming = false
      @connect(self.gateway)

  gatewayMessage: (data, flags) ->
    if flags
      msg = if flags.binary then JSON.parse(zlib.inflateSync(data).toString()) else JSON.parse(data)
      HELLO = 10
      HEARTBEAT_ACK = 11
      DISPATCH = 0
      INVALID_SESSION = 9
      switch msg.op
        when HELLO then @helloPackage(msg)
        when HEARTBEAT_ACK then @heartbeatACK(msg)
        when DISPATCH then @dispatcher.parseDispatch(msg)
        when INVALID_SESSION then @handleInvalidSession(msg)
        else
          utils.debug("Unhandled op: "+msg.op, "warn")
    else
      utils.debug("No flags returned","warn")

module.exports = ClientConnection
