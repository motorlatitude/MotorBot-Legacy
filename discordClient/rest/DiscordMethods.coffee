u = require('../utils.coffee')
utils = new u()

class DiscordMethods

  constructor: (@requester) ->

  ###
  # CHANNEL
  ###

  createMessage: (content, channel_id, options) ->
    data = {content: content, tts: "false"}
    if options
      if options.tts
        data.tts = options.tts.toString()
      if options.nonce
        data.nonce = options.nonce.toString()
    @requester.sendRequest("POST", "/channels/"+channel_id+"/messages", data)

  createReaction: (emoji, channel_id, message_id) ->
    @requester.sendRequest("PUT", "/channels/"+channel_id+"/messages/"+message_id+"/reactions/"+emoji+"/@me")

  deleteReaction: (emoji, channel_id, message_id) ->
    @requester.sendRequest("DELETE", "/channels/"+channel_id+"/messages/"+message_id+"/reactions/"+emoji+"/@me")

  deleteUserReaction: (emoji, channel_id, message_id, user_id) ->
    @requester.sendRequest("DELETE", "/channels/"+channel_id+"/messages/"+message_id+"/reactions/"+emoji+"/"+user_id)

  deleteAllReactions: (channel_id, message_id) ->
    @requester.sendRequest("DELETE", "/channels/"+channel_id+"/messages/"+message_id+"/reactions")

  editMessage: (content, channel_id, message_id) ->
    @requester.sendRequest("PATCH", "/channels/"+channel_id+"/messages/"+message_id, {"content": content})

  deleteMessage: (channel_id, message_id) ->
    @requester.sendRequest("DELETE", "/channels/"+channel_id+"/messages/"+message_id)

  pinMessage: (channel_id, message_id) ->
    @requester.sendRequest("PUT", "/channels/"+channel_id+"/pins/"+message_id)

  deletePinnedMessage: (channel_id, message_id) ->
    @requester.sendRequest("DELETE", "/channels/"+channel_id+"/pins/"+message_id)

  uploadFile: (content, file, filename, options) ->
    data = {content: content, tts: "false"}
    if options
      if options.tts
        data.tts = options.tts.toString()
      if options.nonce
        data.nonce = options.nonce.toString()
    @requester.sendUploadRequest("POST","/channels/"+channel_id+"/messages", data, file, filename)

  modifyTextChannel: (channel_id, options) ->
    @requester.sendRequest("PATCH", "/channels/"+channel_id, options)

  modifyVoiceChannel: (channel_id, options) ->
    @requester.sendRequest("PATCH", "/channels/"+channel_id, options)

  deleteChannel: (channel_id) ->
    @requester.sendRequest("DELETE", "/channels/"+channel_id)

  getMessages(channel_id, options) ->
    @requester.sendRequest("GET", "/channels/"+channel_id+"/messages", options)

module.exports = DiscordMethods