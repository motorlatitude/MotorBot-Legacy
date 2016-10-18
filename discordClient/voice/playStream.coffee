{EventEmitter} = require('events')
u = require '../utils.coffee'
utils = new u()
VoicePacket = require './voicePacket.coffee'
childProc = require 'child_process'
#ffmpeg = require 'fluent-ffmpeg'

class playStream extends EventEmitter
  
  ###
  # PRIVATE METHODS
  ###
  
  constructor: (stream, @voiceConnection, @discordClient) ->
    @glob_stream = stream
    #setup stream
    utils.debug("Setting up new stream")
    @ffmpegDone = false
    @emptyPacket = false
    @outputStream = null;
    self = @
    if typeof(stream) == "string"
      @enc = childProc.spawn('ffmpeg', [
        '-hide_banner',
        '-i', stream,
        '-f', 's16le',
        '-ar', '48000',
        '-ss', 0,
        '-ac', 2,
        'pipe:1'
      ]).on('error', (e) ->
        utils.debug("FFMPEG encoding error: "+e.toString(),"error")
      )
    else
      @enc = childProc.spawn('ffmpeg', [
        '-hide_banner',
        '-i', '-',
        '-f', 's16le',
        '-ar', '48000',
        '-ss', 0,
        '-ac', 2,
        'pipe:1'
      ]).on('error', (e) ->
        utils.debug("FFMPEG encoding error: "+e.toString(),"error")
      )
      stream.pipe(@enc.stdin)

    @enc.on('error', (err) ->
      utils.debug("Error Occurred: "+err.toString(),"error")
    )

    @enc.stdout.on('error', (err) ->
      utils.debug("Error Occurred: "+err.toString(),"error")
    )

    @enc.stdout.once('end', () ->
      utils.debug("Stdout END")
      self.enc.kill()
    )

    @enc.once('close', (code, signal) ->
      utils.debug("Enc CLOSE")
      self.enc.stdout.emit("end")
      self.ffmpegDone = true
    )
    ###
    @enc.stderr.on('data', (d) ->
      console.log 'data: '+d
    )
    ###
    @enc.stdout.once('readable', () ->
      utils.debug("Storing Voice Packets")
      self.packageList = []
      self.opusEncoder = self.voiceConnection.opusEncoder
      self.packageData(self.enc.stdout, new Date().getTime(), 1)
      self.stopSend = false
      self.emit("ready")
    )

  packageData: (stream, startTime, cnt) ->
    channels = 2 #just assume it's 2 for now
    self = @
    if stream
      streamBuff=stream.read(1920*channels)
      if stream.destroyed
        return
      self.voiceConnection.sequence = if (self.voiceConnection.sequence + 1) < 65535 then self.voiceConnection.sequence += 1 else self.voiceConnection.sequence = 0
      self.voiceConnection.timestamp = if (self.voiceConnection.timestamp + 960) < 4294967295 then self.voiceConnection.timestamp += 960 else self.voiceConnection.timestamp = 0

      if streamBuff && streamBuff.length != 1920 * channels
        newBuffer = new Buffer(1920 * channels).fill(0)
        streamBuff.copy(newBuffer)
        streamBuff = newBuffer

      if streamBuff
        # TODO volume transformation
        encoded = @opusEncoder.encode(streamBuff, 1920)
        audioPacket = new VoicePacket(encoded, @, @voiceConnection)
        @packageList.push(audioPacket)
        nextTime = startTime + (cnt+1) * 20
        return setTimeout(() ->
          self.packageData(stream, startTime, cnt + 1)
        , 20 + (nextTime - new Date().getTime()));
    else
      return setTimeout(() ->
        self.packageData(stream, startTime, cnt)
      , 200);

  send: (startTime, cnt) ->
    self = @
    if !@stopSend
      packet = @packageList.shift()
      if @ffmpegDone && @packageList.length < 1
        utils.debug "Stream Done :("
        @stopSend = true
        self.emit("streamDone")
      if !packet
        packet = new Buffer([0xF8, 0xFF, 0xFE]) #5 frames of silence
        utils.debug("Sending Empty Packet","debug")
      @voiceConnection.udpClient.send(packet, 0, packet.length, @voiceConnection.port, @voiceConnection.endpoint.split(":")[0], (err, bytes) ->
        if err
          utils.debug("Error Sending Voice Packet: "+err.toString(),"error")
      )
      nextTime = startTime + (cnt+1) * 15
      return setTimeout(() ->
        self.send(startTime, cnt + 1)
      , 15 + (nextTime - new Date().getTime()))
    else
      packet = new Buffer([0xF8, 0xFF, 0xFE]) #5 frames of silence
      @voiceConnection.udpClient.send(packet, 0, packet.length, @voiceConnection.port, @voiceConnection.endpoint.split(":")[0], (err, bytes) ->
        if err
          utils.debug("Error Sending Voice Packet: "+err.toString(),"error")
        else
          self.voiceConnection.setSpeaking(false)
          utils.debug("Sending Empty Packet","debug")
          self.emit("paused")
      )


  stopSending: () ->
    @stopSend = true

  ###
  # PUBLIC METHODS
  ###
  
  pause: () ->
    utils.debug("Pausing Stream")
    @voiceConnection.setSpeaking(false)
    @stopSending()

  play: () ->
    #start sending voice data and turn speaking on for bot
    utils.debug("Playing Stream")
    @stopSend = false
    @voiceConnection.setSpeaking(true)
    self = @
    self.send(new Date().getTime(), 1)

  stop: () ->
    #stop sending voice data and turn speaking off for bot
    utils.debug("Stopping Stream")
    @emit("streamDone")
    self = @
    try
      @stopSending()
      @glob_stream.end()
      @glob_stream.destroy()
      @enc.kill("SIGSTOP")
      setTimeout(() ->
        #completely kill the process after delay
        self.enc.kill()
      ,1000)
    catch err
      utils.debug("Error stopping sending of voice packets: "+err.toString(),"error")

  destroy: () ->
    delete @

  setVolume: (streamObj) ->

  getVolume: (streamObj) ->
module.exports = playStream