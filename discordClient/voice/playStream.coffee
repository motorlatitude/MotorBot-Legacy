{EventEmitter} = require('events')
u = require '../utils.coffee'
utils = new u()
VoicePacket = require './voicePacket.coffee'
childProc = require 'child_process'
Opus = require 'node-opus'

class playStream extends EventEmitter

  constructor: (stream, @voiceConnection) ->
    #setup stream
    utils.debug("Setting up new stream")
    self = @
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

    @enc.stdout.once('readable', () ->
      utils.debug("Storing Voice Packets")
      self.packageList = []
      self.startTime = new Date().getTime()
      self.opusEncoder = new Opus.OpusEncoder(48000, 2)
      self.sequence = 0
      self.timestamp = 0
      self.packageData(self.enc.stdout, 1)
      self.emit("ready")
    )

  packageData: (stream, cnt) ->
    channels = 2 #just assume it's 2 for now
    self = @

    streamBuff = stream.read(1920*channels)

    if stream.destroyed
      return
    @sequence = if (@sequence + 1) < 65535 then @sequence += 1 else @sequence = 0
    @timestamp = if (@timestamp + 960) < 4294967295 then @timestamp += 960 else @timestamp = 0

    if streamBuff && streamBuff.length != 1920 * channels
      newBuffer = new Buffer(1920 * channels).fill(0)
      streamBuff.copy(newBuffer)
      streamBuff = newBuffer

    if streamBuff

      # TODO volume transformation

      encoded = @opusEncoder.encode(streamBuff, 1920)
      audioPacket = new VoicePacket(encoded, @, @voiceConnection)
      @packageList.push(audioPacket)

    nextTime = @startTime + (cnt+1) * 20
    return setTimeout(() ->
      self.packageData(stream, cnt + 1)
    , 20 + (nextTime - new Date().getTime()));

  send: (startTime, cnt) ->
    packet = @packageList.shift()
    emptyPacket = false
    if !packet
      packet = new Buffer([0xF8, 0xFF, 0xFE]) #5 frames of silence
      emptyPacket = true
    @voiceConnection.udpClient.send(packet, 0, packet.length, @voiceConnection.port, @voiceConnection.endpoint.split(":")[0], (err, bytes) ->
      if err
        utils.debug("Error Sending Voice Packet: "+err.toString(),"error")
    )
    self = @
    nextTime = startTime + (cnt+1) * 20
    return setTimeout(() ->
      self.send(startTime, cnt + 1)
    , 20 + (nextTime - new Date().getTime()));


module.exports = playStream