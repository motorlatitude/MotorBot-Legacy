
req = require 'request'


class VoiceStateUpdate

  constructor: (App, client, Logger, @vc) ->
    @voiceData = {}
    # @AttachEventListener()
    # @ParseVoiceData()

  ParseVoiceData: () ->
    self = @
    for id, user of self.voiceData
      if id != "169554882674556930" && user.data.length > 0 && (new Date().getTime() - user.lastSpoke) > 1000 # wait 1 second and then analyze
        console.log("Received voice packet, trying to understand it")

        user.data = Buffer.alloc(0)
    setTimeout(() ->
      self.ParseVoiceData()
    , 1000)

  AttachEventListener: () ->
    self = @
    if self.vc.voiceHandler.udpClient
      console.log("Attached Voice Listener")
      self.vc.voiceHandler.udpClient.on("VOICE_PACKET", (obj) ->
        if self.voiceData[obj.id]
          self.voiceData[obj.id].lastSpoke = new Date().getTime()
          self.voiceData[obj.id].data = Buffer.concat(self.voiceData[obj.id].data, obj.data)
        else
          self.voiceData[obj.id] = {}
          self.voiceData[obj.id].lastSpoke = new Date().getTime()
          self.voiceData[obj.id].data = obj.data
      )
    else
      setTimeout(() ->
        self.AttachEventListener()
      ,1000)

module.exports = VoiceStateUpdate