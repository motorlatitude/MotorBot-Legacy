
class VoiceUpdateEvent

  constructor: (@App, @Client, @Logger, type, data) ->
    if type == "speaking"
      @SpeakingEvent(data)
    else
      @Logger.write("Unknown VoiceUpdate Event Type: "+type)

  SpeakingEvent: (data) ->
    @App.WebSocket.broadcast(JSON.stringify({type: "VOICE_UPDATE_SPEAKING", d:data}))

module.exports = VoiceUpdateEvent