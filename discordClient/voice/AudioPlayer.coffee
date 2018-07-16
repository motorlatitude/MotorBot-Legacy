{EventEmitter} = require('events')
u = require '../utils.coffee'
fs = require 'fs'
utils = new u()
VoicePacket = require './voicePacket.coffee'
childProc = require 'child_process'
chunker = require 'stream-chunker'

class AudioPlayer extends EventEmitter
  
  ###
  # PRIVATE METHODS
  ###
  
  constructor: (stream, @voiceConnection, @discordClient) ->
    utils.debug("New AudioPlayer constructed")
    @glob_stream = stream
    #setup stream
    @ffmpegDone = false
    @streamFinished = false
    @streamBuffErrorCount = 0
    @seekCnt = 0
    @seekPosition = 0
    @packageList = []
    self = @
    self.enc = childProc.spawn('ffmpeg', [
      '-i', 'pipe:0',
      '-f', 's16le',
      '-ar', '48000',
      '-ss', '0',
      '-ac', '2',
      '-af', 'bass=g=4:f=140:w=0.7',
      '-vn',
      '-copy_unknown',
      '-loglevel', 'verbose',
      'pipe:1'
    ]).on('error', (e) ->
      utils.debug("FFMPEG encoding error: "+e.toString(),"error")
    )
    chnkr = chunker(1920*2, {
      flush: true,
      align: true
    })
    self.opusEncoder = self.voiceConnection.opusEncoder
    chnkr.on("data", (chunk) ->
      self.packageData(chunk)
    )
    stream.pipe(self.enc.stdin)
    self.enc.stdout.pipe(chnkr)

    self.enc.on('error', (err) ->
      utils.debug("Error Occurred: "+err.toString(),"error")
    )

    self.enc.stdout.on('error', (err) ->
      utils.debug("Error Occurred: "+err.toString(),"error")
    )

    self.enc.stdout.once('end', () ->
      utils.debug("Stdout END")
      self.enc.kill()
    )

    self.enc.once('close', (code, signal) ->
      utils.debug "FFMPEG Stream Closed"
      self.enc.stdout.emit("end")
      self.ffmpegDone = true
    )

    self.enc.stderr.once('data', (d) ->
      utils.debug("Storing Voice Packets")
      self.stopSend = false
      self.emit("ready")
    )

    self.enc.stderr.on('data', (d) ->
      utils.debug("[STDERR]: "+d)
      if d.toString().match(/time=(.*?)\s/gmi)
        regexMatch = /time=(.*?)\s/gmi
        matches = regexMatch.exec(d.toString())
        time = matches[1]
        a = time.split(':')
        seconds = (+a[0]) * 60 * 60 + (+a[1]) * 60 + (+a[2].split(".")[0])
        self.emit("progress", seconds)
    )

    self.enc.stdout.once('readable', () ->
      utils.debug("ffmpeg stream readable")
    )

    stream.on('close', () ->
      utils.debug("User Stream Closed","warn")
    )

    stream.on('error', (err) ->
      utils.debug("User Stream Error","error")
      console.log err
    )

    stream.on('end', () ->
      utils.debug "User Stream Ended"
    )

  packageData: (chunk) ->
    if chunk && chunk instanceof Buffer
      @packageList.push(chunk)

  sendToVoiceConnection: (startTime, cnt) ->
    self = @
    if !@stopSend
      @voiceConnection.buffer_size = new Date(self.packageList.length*20).toISOString().substr(11, 8)
      packet = @packageList.shift()
      if packet
        @voiceConnection.streamPacketList.push(packet)
        @emit("streamTime",self.seekCnt*20)
        @seekPosition = self.seekCnt*20
      else if @ffmpegDone && !@streamFinished
        @streamFinished = true
        @sendEmptyBuffer()
        utils.debug("Stream Done in sendToVoiceConnection")
        @emit("streamDone")
        @seekPosition = 0
        self.destroy()
      nextTime = startTime + (cnt+1) * 20
      self.seekCnt++
      return setTimeout(() ->
        self.sendToVoiceConnection(startTime, cnt + 1)
      , 20 + (nextTime - new Date().getTime()));
    else
      utils.debug("Stream Paused via stopSend")
      @sendEmptyBuffer()
      @emit("paused")

  sendEmptyBuffer: () ->
    streamBuff = new Buffer(1920*2).fill(0)
    if @packageList
      @voiceConnection.streamPacketList.push(streamBuff)
    else
      utils.debug("Couldn't send empty buffer","error")

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
    @voiceConnection.streamPacketList = [] #empty current packet list to be sent to avoid stuttering
    @sendEmptyBuffer()
    @voiceConnection.setSpeaking(false)
    self = @
    self.stopSending()
    try
      self.glob_stream.unpipe()
      self.enc.kill("SIGSTOP")
      self.enc.kill()
      self.emit("streamDone")
      self.destroy()
    catch err
      self.emit("streamDone")
      self.destroy()
      utils.debug("Error stopping sending of voice packets: "+err.toString(),"error")

  stop_kill: () ->
    utils.debug("Stopping Stream")
    @voiceConnection.streamPacketList = [] #empty current packet list to be sent to avoid stuttering
    @sendEmptyBuffer()
    @voiceConnection.setSpeaking(false)
    self = @
    self.stopSending()
    try
      self.glob_stream.unpipe()
      self.enc.kill("SIGSTOP")
      self.enc.kill()
      self.destroy()
    catch err
      self.destroy()
      utils.debug("Error stopping sending of voice packets: "+err.toString(),"error")

  destroy: () ->
    delete @

  setVolume: (volume) ->
    @voiceConnection.volume = volume
    multiplier =  Math.pow(volume, 1.660964);
    console.log "Init Volume Multiplier: "+multiplier

  getVolume: () ->
    return @voiceConnection.volume

module.exports = AudioPlayer