u = require('../utils.coffee')
utils = new u()
Constants = require './../constants.coffee'
ws = require 'ws'
zlib = require 'zlib'
UDPClient = require './udpClient'

class VoiceConnection

  ###
  # PRIVATE METHODS
  ###

  constructor: (@discordClient) ->
    utils.debug("New Voice Connection Started")

  connect: (params) ->
    @token = params.token
    @guild_id = params.guild_id
    @endpoint = params.endpoint
    @user_id = @discordClient.internals.user_id
    @session_id = @discordClient.internals.session_id
    @vws = null
    @vhb = null
    utils.debug("Generating new voice WebSocket connection")
    @vws = new ws("wss://"+@endpoint.split(":")[0])
    self = @
    @vws.once('open', () -> self.voiceGatewayOpen())
    @vws.once('close', () -> self.voiceGatewayClose())
    @vws.once('error', (err) -> self.voiceGatewayError(err))
    @vws.on('message', (msg, flags) -> self.voiceGatewayMessage(msg, flags))

  voiceGatewayOpen: (guild_id) ->
    utils.debug("Voice gateway server is open")
    #send identity package
    idpackage = {
      "op": 0
      "d": {
        "server_id": @guild_id,
        "user_id": @user_id,
        "session_id": @session_id,
        "token": @token
      }
    }
    @vws.send(JSON.stringify(idpackage))

  voiceGatewayClose: () ->
    utils.debug("Voice gateway server is CLOSED","warn")
    #reset voice data, we need full reconnect
    clearInterval(@vhb)

  voiceGatewayError: (err, guild_id) ->
    utils.debug("Voice gateway server encountered an error: "+err.toString(),"error")

  voiceGatewayMessage: (data, flags) ->
    msg = if flags.binary then JSON.parse(zlib.inflateSync(data).toString()) else JSON.parse(data)
    switch msg.op
      when Constants.voice.PacketCodes.READY then @handleReady(msg)
      when Constants.voice.PacketCodes.HEARTBEAT then @handleHeartbeat(msg)
      when Constants.voice.PacketCodes.SPEAKING then @handleSpeaking(msg)
      when Constants.voice.PacketCodes.SESSION_DESC then @handleSession(msg)
      else
        utils.debug("Unhandled Voice OP: "+msg.op,"warn")

  handleReady: (msg) ->
    #start HB
    self = @
    @vhb = setInterval(() ->
      hbpackage = {
        "op": 3,
        "d": null
      }
      self.gatewayPing = new Date().getTime()
      self.vws.send(JSON.stringify(hbpackage))
    , msg.d.heartbeat_interval)

    conn = {
      "ssrc": msg.d.ssrc
      "port": msg.d.port
      "endpoint": @endpoint.split(":")[0]
    }
    #start UDP Connection
    @udpClient = new UDPClient()
    @udpClient.init(conn)

    @udpClient.on('ready', (localIP, localPort) ->
      selectProtocolPayload = {
        "op": 1
        "d":{
          "protocol": "udp"
          "data":{
            "address": localIP
            "port": parseInt(localPort)
            "mode": "xsalsa20_poly1305"
          }
        }
      }
      self.vws.send(JSON.stringify(selectProtocolPayload))
    )

  handleSpeaking: (msg) ->
    #user speaking on the server, ignore atm

  handleHeartbeat: (msg, guild_id) ->
    ping = new Date().getTime() - @gatewayPing
    utils.debug("Voice Heartbeat Sent ("+ping+"ms)")

  handleSession: (msg) ->
    @secretKey = msg.d.secret_key
    @mode = msg.d.mode
    utils.debug("Received Voice Session Description")

  ###
  # PUBLIC FACING METHODS
  ###

module.exports = VoiceConnection
