u = require('../utils.coffee')
utils = new u()

class TextChannel

  constructor: (@client, channel) ->
    @id = channel.id
    @guild_id = channel.guild_id
    @name = channel.name
    @type = channel.type
    @position = channel.position
    @is_private = channel.is_private
    @permission_overwrites = channel.permission_overwrites
    @topic = channel.topic
    @last_message_id = channel.last_message_id

  sendMessage: (content, options) ->
    @client.rest.methods().createMessage(content, @id, options)

  reply: (content, options) ->
    @sendMessage(content, options)

  sendMessageWithFile: (content, filepath, filename, options) ->
    @client.rest.methods().uploadFile(content, filepath, filename, options)

  modify: (options) ->

  delete: () -> #CAUTION

  getMessages: (options) ->

  getPinnedMessages: () ->

  getMessage: (messageId) ->

  deleteMessages: (messageIds) ->

  setPermissions: (allow, deny, type) ->

  deletePermission: (overwriteId) ->

  getInvites: () ->

  createInvite: (max_age, max_uses, temporary, unique) ->

  typing: () ->


module.exports = TextChannel