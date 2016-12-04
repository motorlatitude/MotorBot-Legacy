{EventEmitter} = require('events')
u = require '../utils.coffee'
fs = require 'fs'
utils = new u()
VoicePacket = require './voicePacket.coffee'
childProc = require 'child_process'

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
    @outputStream = null
    @streamFinished = false
    self = @
    @enc = childProc.spawn('ffmpeg', [
      '-i', 'pipe:0',
      '-f', 's16le',
      '-ar', '48000',
      '-ss', '0',
      '-ac', '2',
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

    @enc.stderr.on('data', (d) ->
      #console.log 'data: '+d
    )

    @enc.stdout.once('readable', () ->
      utils.debug("Storing Voice Packets")
      self.packageList = []
      self.opusEncoder = self.voiceConnection.opusEncoder
      self.emptyPackets = 0
      self.packageData(self.enc.stdout, new Date().getTime(), 1)
      self.stopSend = false
      self.emit("ready")
    )

  packageData: (stream, startTime, cnt) ->
    channels = 2 #just assume it's 2 for now
    self = @
    if stream
      streamBuff=stream.read(1920*channels)
      if streamBuff && streamBuff.length != 1920 * channels
        newBuffer = new Buffer(1920 * channels).fill(0)
        streamBuff.copy(newBuffer)
        streamBuff = newBuffer
      if streamBuff
        @packageList.push(streamBuff)
        nextTime = startTime + (cnt+1) * 20
        return setTimeout(() ->
          self.packageData(stream, startTime, cnt + 1)
        , 20 + (nextTime - new Date().getTime()));
    else
      return setTimeout(() ->
        self.packageData(stream, startTime, cnt)
      , 200);

  sendToVoiceConnection: (startTime, cnt) ->
    self = @
    if !@stopSend
      packet = @packageList.shift()
      if packet
        @voiceConnection.streamPacketList.push(packet)
      else if @ffmpegDone && !@streamFinished
        @streamFinished = true
        @sendEmptyBuffer()
        @emit("streamDone")
      nextTime = startTime + (cnt+1) * 20
      return setTimeout(() ->
        self.sendToVoiceConnection(startTime, cnt + 1)
      , 20 + (nextTime - new Date().getTime()));
    else
      @sendEmptyBuffer()
      @emit("paused")

  sendEmptyBuffer: () ->
    streamBuff = new Buffer(1920).fill(0)
    encoded = @opusEncoder.encode(streamBuff, 1920)
    audioPacket = new VoicePacket(encoded, @, @voiceConnection)
    @voiceConnection.packageList.push(audioPacket)

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
    self = @
    utils.debug("Playing Stream")
    self.stopSend = false
    self.voiceConnection.setSpeaking(true)
    @sendEmptyBuffer()
    #self.packageData(@enc.stdout, new Date().getTime(), 1)
    self.sendToVoiceConnection(new Date().getTime(), 1)

  stop: () ->
    #stop sending voice data and turn speaking off for bot
    utils.debug("Stopping Stream")
    @emit("streamDone")
    @sendEmptyBuffer()
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