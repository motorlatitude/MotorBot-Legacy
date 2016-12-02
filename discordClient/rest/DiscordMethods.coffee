u = require('../utils.coffee')
utils = new u()
Message = require '../resources/Message'

class DiscordMethods

  constructor: (@client, @requester) ->

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

  bulkDeleteMessages: (channel_id, message_ids) ->
    @requester.sendRequest("POST", "/channels/"+channel_id+"/messages/bulk-delete",{messages: message_ids})

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

  getMessages: (channel_id, options) ->
    self = @
    new Promise((resolve, reject) ->
      self.requester.sendRequest("GET", "/channels/"+channel_id+"/messages", options).then((response) ->
            returnMessages = []
            for msg in response.body
              returnMessages.push(new Message(self.client, msg))
            resolve({messages: returnMessages, httpResponse: response.httpResponse})
      ).catch((err) ->
        reject(err)
      )
    )

  getPinnedMessages: (channel_id) ->
    self = @
    new Promise((resolve, reject) ->
      self.requester.sendRequest("GET", "/channels/"+channel_id+"/pins").then((response) ->
          returnMessages = []
          for msg in response.body
            returnMessages.push(new Message(self.client, msg))
          resolve({messages: returnMessages, httpResponse: response.httpResponse})
      ).catch((err) ->
        reject(err)
      )
    )

  getMessage: (channel_id, message_id) ->
    self = @
    return new Promise((resolve, reject) ->
      self.requester.sendRequest("GET", "/channels/"+channel_id+"/messages/"+message_id, options).then((response) ->
        resolve({message: new Message(self.client, response.body), httpResponse: response.httpResponse})
      ).catch((err) ->
        reject(err)
      )
    )

  setChannelPermissions: (channel_id, overwrite_id, options) ->
    @requester.sendRequest("PUT", "/channels/"+channel_id+"/permissions/"+overwrite_id, options)

  deleteChannelPermissions: (channel_id, overwrite_id) ->
    @requester.sendRequest("DELETE", "/channels/"+channel_id+"/permissions/"+overwrite_id)

  getChannelInvites:(channel_id) ->
    self = @
    return new Promise((resolve, reject) ->
      self.requester.sendRequest("GET","/channels/"+channel_id+"/invites").then((response) ->
        resolve({invite: response.body, httpResponse: response.httpResponse})
      ).catch((err) ->
        reject(err)
      )
    )
  createChannelInvite:(channel_id, max_age, max_uses, temporary, unique) ->
    self = @
    return new Promise((resolve, reject) ->
      self.requester.sendRequest("POST","/channels/"+channel_id+"/invites",{max_age: max_age, max_uses: max_uses, temporary: temporary, unique: unique}).then((response) ->
        resolve({invite: response.body, httpResponse: response.httpResponse})
      ).catch((err) ->
        reject(err)
      )
    )
  triggerTypingIndicator:(channel_id) ->
    @requester.sendRequest("POST","/channels/"+channel_id+"/typing")

module.exports = DiscordMethods