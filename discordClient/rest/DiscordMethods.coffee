u = require('../utils.coffee')
utils = new u()

class DiscordMethods

  constructor: (@requester) ->

  createMessage: (content, channel_id, options) ->
    data = {content: content, tts: "false"}
    if options
      if options.tts
        data.tts = options.tts.toString()
      if options.nonce
        data.nonce = options.nonce.toString()
    @requester.sendRequest("POST", "/channels/"+channel_id+"/messages", data)

  createReaction: (emoji, channel_id, message_id) ->
    @requester.sendRequest("PUT", "/channels/"+channel_id+"/messages/"+message_id+"/reactions/"+emoji+"/169554882674556930")

  uploadFile: (content, file, filename, options) ->
    data = {content: content, tts: "false"}
    if options
      if options.tts
        data.tts = options.tts.toString()
      if options.nonce
        data.nonce = options.nonce.toString()
    @requester.sendUploadRequest("POST","/channels/"+channel_id+"/messages", data, file, filename)

module.exports = DiscordMethods