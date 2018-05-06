u = require('../utils.coffee')
utils = new u()
Message = require '../resources/Message'
TextChannel = require '../resources/TextChannel'
VoiceChannel = require '../resources/VoiceChannel'

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
      if options.embed
        data.embed = options.embed
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

  uploadFile: (content, channel_id, file, filename, options) ->
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
        resolve(returnMessages)
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
          resolve(returnMessages)
      ).catch((err) ->
        reject(err)
      )
    )

  getMessage: (channel_id, message_id) ->
    self = @
    return new Promise((resolve, reject) ->
      self.requester.sendRequest("GET", "/channels/"+channel_id+"/messages/"+message_id).then((response) ->
        resolve(new Message(self.client, response.body))
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
        invites = response.body
        for invite in invites
          invite.channel = self.client.channels[invite.channel.id]
        resolve(response.body)
      ).catch((err) ->
        reject(err)
      )
    )
  createChannelInvite:(channel_id, max_age, max_uses, temporary, unique) ->
    self = @
    return new Promise((resolve, reject) ->
      self.requester.sendRequest("POST","/channels/"+channel_id+"/invites",{max_age: max_age, max_uses: max_uses, temporary: temporary, unique: unique}).then((response) ->
        invite = response.body
        invite.channel = self.client.channels[invite.channel.id]
        resolve(response.body)
      ).catch((err) ->
        reject(err)
      )
    )
  triggerTypingIndicator:(channel_id) ->
    @requester.sendRequest("POST","/channels/"+channel_id+"/typing")

  addRecipient: (channel_id, user_id, options) ->
    @requester.sendRequest("PUT","/channels/"+channel_id+"/recipients/"+user_id,options)

  removeRecipient: (channel_id, user_id) ->
    @requester.sendRequest("DELETE","/channels/"+channel_id+"/recipients/"+user_id)

  ###
  # GUILD
  ###

  modify_guild: (guild_id, options) ->
    @requester.sendRequest("PATCH","/guilds/"+guild_id, options)
    
  deleteGuild: (guild_id) ->
    @requester.sendRequest("DELETE","/guilds/"+guild_id)

  getChannels: (guild_id) ->
    @requester.sendRequest("GET","/guilds/"+guild_id+"/channels")



module.exports = DiscordMethods