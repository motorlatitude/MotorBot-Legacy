nacl = require('tweetnacl')

class VoicePacket

  constructor: (data, playStream, voiceConnection) ->
    mac = if voiceConnection.secretKey then 16 else 0
    packageLength = data.length + 12 + mac

    audioBuffer = data
    returnBuffer = new Buffer(packageLength).fill(0)

    returnBuffer[0] = 0x80
    returnBuffer[1] = 0x78

    returnBuffer.writeUIntBE(voiceConnection.sequence, 2, 2)
    returnBuffer.writeUIntBE(voiceConnection.timestamp, 4, 4)
    returnBuffer.writeUIntBE(voiceConnection.ssrc, 8, 4)

    if voiceConnection.secretKey
      nonce = new Buffer(24).fill(0)
      returnBuffer.copy(nonce, 0, 0, 12)
      audioBuffer = nacl.secretbox(new Uint8Array(data), new Uint8Array(nonce), new Uint8Array(voiceConnection.secretKey))

    for i in [0...audioBuffer.length] by 1
      returnBuffer[i+12] = audioBuffer[i]

    return returnBuffer


module.exports = VoicePacket