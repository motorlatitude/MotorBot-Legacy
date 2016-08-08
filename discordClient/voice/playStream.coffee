u = require '../utils.coffee'
utils = new u()
VoicePacket = require './voicePacket.coffee'
childProc = require 'child_process'
Opus = require 'node-opus'

class playStream

  constructor: (stream) ->
    #setup stream
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
    stream.pipe(@enc.stdin)

    @enc.stdout.once('readable', () ->
      @packageList = []
      @startTime = new Date().getTime()
      @opusEncoder = new Opus.OpusEncoder(48000, 2);
      @sequence = 0
      @timestamp = 0
      @packageData(@enc.stdout, 1)
    )

  packageData: (stream, cnt) ->
    channels = 2 #just assume it's 2 for now

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

      encoded = @opusEncoder(streamBuff, 1920)
      audioPacket = new VoicePacket(encoded,@)
      @packageList.push(audioPacket)

  send: () ->



module.exports = playStream