Constants = require './../constants.coffee'
ws = require 'ws'
zlib = require 'zlib'
fs = require 'fs'
Opus = require 'node-opus'
UDPClient = require './udpClient'
audioPlayer = require './AudioPlayer.coffee'
VoicePacket = require './voicePacket.coffee'

class VoiceConnection

  ###
  # PRIVATE METHODS
  ###

  constructor: (@discordClient) ->
    @discordClient.utils.debug("New Voice Connection Started")
    @sequence = 0
    @timestamp = 0
    @timestamp_inc = (48000 / 100) * 2;

  connect: (params) ->
    @token = params.token
    @discordClient.utils.debug("Setting Guild For Voice Handler")
    @discordClient.utils.debug("Guild ID: "+params.guild_id)
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
    @AudioPlayers = []
    @discordClient.utils.debug("Generating new voice WebSocket connection: "+@endpoint)
    @vws = new ws("wss://" + @endpoint.split(":")[0]) #using version 3 now
    self = @
    @opusEncoder = new Opus.OpusEncoder(48000, 2)
    @vws.once('open', () -> self.voiceGatewayOpen())
    @vws.once('close', () -> self.voiceGatewayClose())
    @vws.once('error', (err) -> self.voiceGatewayError(err))
    @vws.on('message', (msg) -> self.voiceGatewayMessage(msg))

  voiceGatewayOpen: (guild_id) ->
    @discordClient.utils.debug("[VOICESOCKET]: Connected to Voice Gateway Server: " + @endpoint, "info")
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
    @discordClient.utils.debug("[VOICESOCKET] ~> ["+@endpoint.split(":")[0].toUpperCase()+"]: Sent Identification Payload")

  voiceGatewayClose: () ->
    @discordClient.utils.debug("[VOICESOCKET] Voice gateway server is CLOSED", "warn")
    #reset voice data, we need full reconnect
    clearInterval(@vhb)

  voiceGatewayError: (err, guild_id) ->
    @discordClient.utils.debug("[VOICESOCKET] Voice gateway server encountered an error: " + err.toString(), "error")

  voiceGatewayMessage: (data) ->
    msg = if typeof data != "string" then JSON.parse(zlib.inflateSync(data).toString()) else JSON.parse(data)
    switch msg.op
      when Constants.voice.PacketCodes.READY then @handleReady(msg)
      when Constants.voice.PacketCodes.HEARTBEAT then @handleHeartbeat(msg)
      when Constants.voice.PacketCodes.SPEAKING then @handleSpeaking(msg)
      when Constants.voice.PacketCodes.SESSION_DESC then @handleSession(msg)
      when Constants.voice.PacketCodes.HELLO then @discordClient.utils.debug("Got Heartbeat Interval", "info")
      when Constants.voice.PacketCodes.CLIENT_CONNECT then @discordClient.utils.debug("A client has joined the current voice channel", "info")
      when Constants.voice.PacketCodes.CLIENT_DISCONNECT then @discordClient.utils.debug("A client has disconnected from the current voice channel", "info")
      else
        @discordClient.utils.debug("Unhandled Voice OP: " + msg.op, "warn")

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
      self.discordClient.utils.debug("[VOICESOCKET] ~> ["+self.endpoint.split(":")[0].toUpperCase()+"]: Sent Heartbeat")
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
      self.discordClient.utils.debug("[VOICESOCKET] ~> ["+self.endpoint.split(":")[0].toUpperCase()+"]: Sent UDP Protocol Payload")
      self.packageData(new Date().getTime(), 1)
      self.send(new Date().getTime(), 1)
    )

  handleSpeaking: (msg) ->
    @users[msg.d.user_id] = {ssrc: msg.d.ssrc} #for receiving voice data
    @discordClient.emit("voiceUpdate_Speaking", msg.d)

  handleHeartbeat: (msg, guild_id) ->
    ping = new Date().getTime() - @gatewayPing
    @pings.push(ping)
    @totalPings += ping
    @avgPing = @totalPings / @pings.length
    @discordClient.utils.debug("[VOICESOCKET] <~ ["+@endpoint.split(":")[0].toUpperCase()+"]: Voice Heartbeat Acknowledged (" + ping + "ms - average: " + (Math.round(@avgPing * 100)/100) + "ms)")

  handleSession: (msg) ->
    @secretKey = msg.d.secret_key
    @mode = msg.d.mode
    @discordClient.utils.debug("[VOICESOCKET] <~ ["+@endpoint.split(":")[0].toUpperCase()+"]: Received Voice Session Description")

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
      @discordClient.utils.debug("[VOICESOCKET] ~> ["+@endpoint.split(":")[0].toUpperCase()+"]: Sent Speaking Payload")
    else
      @discordClient.utils.debug("[VOICESOCKET]: WebSocket Connection not open to set bot to speaking", "warn")

  packageData: (startTime, cnt) ->
    channels = 2 #just assume it's 2 for now
    self = @
    streamPacket = @streamPacketList.shift()
    if streamPacket
      streamBuff = streamPacket
      @sequence = if (@sequence + 1) < 65535 then @sequence += 1 else @sequence = 0
      @timestamp = if (@timestamp + @timestamp_inc) < 4294967295 then @timestamp += @timestamp_inc else @timestamp = 0
      out = new Buffer(streamBuff.length);
      i = 0
      while i < streamBuff.length
        if i >= streamBuff.length - 1
          break
        multiplier =  Math.pow(self.volume, 1.660964);
        uint = Math.floor(multiplier * streamBuff.readInt16LE(i))
        # Ensure value stays within 16bit
        if uint > 32767 || uint < -32767
          self.discordClient.utils.debug("Audio Peaking, Lowering Volume","warn")
          self.volume = self.volume - 0.05 #lower volume automatically if we're peaking
        uint = Math.min(32767, uint)
        uint = Math.max(-32767, uint)
        # Write 2 new bytes into other buffer;
        out.writeInt16LE(uint, i)
        i += 2
      streamBuff = out;
      encoded = @opusEncoder.encode(streamBuff, 1920*channels)
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
          self.discordClient.utils.debug("Error Sending Voice Packet: " + err.toString(), "error")
      )
    return setTimeout(() ->
      self.send(startTime, (cnt + 1))
    , 1)

  playFromStream: (stream) ->
    self = @
    if @AudioPlayers.length > 0
      @discordClient.utils.debug("More than one AudioPlayers in this VoiceHandler, killing all AudioPlayers","warn")
      for a in @AudioPlayers
        if a
          a.stop_kill()
          i = self.AudioPlayers.indexOf(a)
          if i > -1
            @AudioPlayers.splice(i,1)
      @streamPacketList = []
      ah = new audioPlayer(stream, @, @discordClient)
      @AudioPlayers.push(ah)
      return ah
    else
      ah = new audioPlayer(stream, @, @discordClient)
      @AudioPlayers.push(ah)
      return ah

  playFromFile: (file) ->
    ps = new audioPlayer(fs.createReadStream(file), @, @discordClient)
    return ps

module.exports = VoiceConnection
