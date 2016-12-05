u = require('../utils.coffee')
utils = new u()

class VoiceConnection

  constructor: (@client, @voiceHandler) ->


  playFromStream: (stream) ->
    self = @
    return new Promise((resolve, reject) ->
      resolve(self.voiceHandler.playFromStream(stream))
    )

  playFromFile: (file) ->
    self = @
    return new Promise((resolve, reject) ->
      resolve(self.voiceHandler.playFromFile(file))
    )

module.exports = VoiceConnection