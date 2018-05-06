u = require('../utils.coffee')
utils = new u()
Constants = require './../constants.coffee'
ws = require 'ws'
zlib = require 'zlib'
fs = require 'fs'
Opus = require 'cjopus'
UDPClient = require './udpClient'
audioPlayer = require './AudioPlayer.coffee'
VoicePacket = require './voicePacket.coffee'

class VoiceConnection

  ###
  # PRIVATE METHODS
  ###

  constructor: (@discordClient) ->
    utils.debug("New Voice Connection Started")
    @sequence = 0
    @timestamp = 0

  connect: (params) ->
    @token = params.token
    @guild_id = params.guild_id
    @endpoint = params.endpoint
    @user_id = @discordClient.internals.user_id
    @session_id = @discordClient.internals.session_id
    @localPort = undefined
    @vws = null
    @vhb = null
    @packageList = []
    @streamPacketList = []
    @connectTime = new Date().getTime()
    @volume = 0.5
    @users = {}
    @pings = []
    @totalPings = 0
    @avgPing = 0
    @bytesTransmitted = 0
    @buffer_size = 0
    utils.debug("Generating new voice WebSocket connection")
    @vws = new ws("wss://" + @endpoint.split(":")[0])
    self = @
    @opusEncoder = new Opus.OpusEncoder(48000, 2)
    @vws.once('open', () -> self.voiceGatewayOpen())
    @vws.once('close', () -> self.voiceGatewayClose())
    @vws.once('error', (err) -> self.voiceGatewayError(err))
    @vws.on('message', (msg, flags) -> self.voiceGatewayMessage(msg, flags))

  voiceGatewayOpen: (guild_id) ->
    utils.debug("Connected to Voice Gateway Server: " + @endpoint, "info")
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
    utils.debug("Voice gateway server is CLOSED", "warn")
    #reset voice data, we need full reconnect
    clearInterval(@vhb)

  voiceGatewayError: (err, guild_id) ->
    utils.debug("Voice gateway server encountered an error: " + err.toString(), "error")

  voiceGatewayMessage: (data, flags) ->
    msg = if flags.binary then JSON.parse(zlib.inflateSync(data).toString()) else JSON.parse(data)
    switch msg.op
      when Constants.voice.PacketCodes.READY then @handleReady(msg)
      when Constants.voice.PacketCodes.HEARTBEAT then @handleHeartbeat(msg)
      when Constants.voice.PacketCodes.SPEAKING then @handleSpeaking(msg)
      when Constants.voice.PacketCodes.SESSION_DESC then @handleSession(msg)
      when 8 then utils.debug("Got Heartbeat Interval", "info")
      else
        utils.debug("Unhandled Voice OP: " + msg.op, "warn")

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

    @ssrc = msg.d.ssrc
    @port = msg.d.port

    conn = {
      "ssrc": msg.d.ssrc
      "port": msg.d.port
      "endpoint": @endpoint.split(":")[0]
    }
    #start UDP Connection
    @udpClient = new UDPClient(@)
    @udpClient.init(conn)

    @udpClient.on('ready', (localIP, localPort) ->
      self.localPort = localPort
      selectProtocolPayload = {
        "op": 1
        "d": {
          "protocol": "udp"
          "data": {
            "address": localIP
            "port": parseInt(localPort)
            "mode": "xsalsa20_poly1305"
          }
        }
      }
      self.vws.send(JSON.stringify(selectProtocolPayload))
      self.packageData(new Date().getTime(), 1)
      self.send(new Date().getTime(), 1)
    )

  handleSpeaking: (msg) ->
    @users[msg.d.user_id] = {ssrc: msg.d.ssrc} #for receiving voice data

  handleHeartbeat: (msg, guild_id) ->
    ping = new Date().getTime() - @gatewayPing
    @pings.push(ping)
    @totalPings += ping
    @avgPing = @totalPings / @pings.length
    utils.debug("Voice Heartbeat Sent (" + ping + "ms - average: " + (Math.round(@avgPing * 100) / 100) + "ms)")

  handleSession: (msg) ->
    @secretKey = msg.d.secret_key
    @mode = msg.d.mode
    utils.debug("Received Voice Session Description")

  setSpeaking: (value) ->
    speakingPackage = {
      "op": 5
      "d": {
        "speaking": value
        "delay": 0
        "ssrc": @ssrc
      }
    }
    if @vws.readyState == @vws.OPEN
      @vws.send(JSON.stringify(speakingPackage))
    else
      utils.debug("Websocket Connection not open to set bot to speaking", "warn")

  packageData: (startTime, cnt) ->
    channels = 2 #just assume it's 2 for now
    self = @
    streamPacket = @streamPacketList.shift()
    if streamPacket
      streamBuff = streamPacket
      @sequence = if (@sequence + 1) < 65535 then @sequence += 1 else @sequence = 0
      @timestamp = if (@timestamp + 960) < 4294967295 then @timestamp += 960 else @timestamp = 0
      out = new Buffer(streamBuff.length);
      multiplier =  Math.pow(self.volume, 1.660964);
      i = 0
      while i < streamBuff.length
        if i >= streamBuff.length - 1
          break
        uint = Math.floor(multiplier * streamBuff.readInt16LE(i))
        # Ensure value stays within 16bit
        uint = Math.min(32767, uint)
        uint = Math.max(-32767, uint)
        # Write 2 new bytes into other buffer;
        out.writeInt16LE(uint, i)
        i += 2
      streamBuff = out;
      encoded = @opusEncoder.encode(streamBuff, 1920)
      audioPacket = new VoicePacket(encoded, @)
      @packageList.push(audioPacket)
      nextTime = startTime + (cnt + 1) * 20
      return setTimeout(() ->
        self.packageData(startTime, cnt + 1)
      , 20 + (nextTime - new Date().getTime()));
    else
      return setTimeout(() ->
        self.packageData(startTime, cnt)
      , 200);

  send: (startTime, cnt) ->
    self = @
    packet = @packageList.shift()
    if packet
      self.bytesTransmitted += packet.length
      @udpClient.send(packet, 0, packet.length, @port, @endpoint.split(":")[0], (err, bytes) ->
        if err
          utils.debug("Error Sending Voice Packet: " + err.toString(), "error")
      )
    nextTime = startTime + (cnt + 1) * 20
    return setTimeout(() ->
      self.send(startTime, (cnt + 1))
    , 20 + (nextTime - new Date().getTime()))

  playFromStream: (stream) ->
    ps = new audioPlayer(stream, @, @discordClient)
    return ps

  playFromFile: (file) ->
    ps = new audioPlayer(fs.createReadStream(file), @, @discordClient)
    return ps

module.exports = VoiceConnection
