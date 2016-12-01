u = require('../utils.coffee')
utils = new u()

class Message

  constructor: (@client, message) ->
    @id = message.id
    @channel_id = message.channel_id
    @channel = @client.channels[@channel_id]
    @guild_id = @channel.guild_id
    @author = message.author
    @content = message.content
    @timestamp = message.timestamp
    @edited_timestamp = message.edited_timestamp
    @tts = message.tts
    @mention_everyone = message.mention_everyone
    @mentions = message.mentions
    @mention_roles = message.mention_roles
    @attachments = message.attachments
    @embeds = message.embeds
    @reactions = message.reactions
    @nonce = message.nonce
    @pinned = message.pinned
    @webhook_id = message.webhook_id

  addReaction: (emoji) ->
    @client.rest.methods().createReaction(emoji, @channel_id, @id)

  deleteReaction: (emoji) ->
    @client.rest.methods().deleteReaction(emoji, @channel_id, @id)

  deleteUsersReaction: (emoji, userId) ->
    @client.rest.methods().deleteUsersReaction(emoji, userId, @id, @channel_id)

  deleteAllReactions: () -> #CAUTION
    @client.rest.methods().deleteAllReactions(@channel_id, @id)

  edit: (content) ->
    @client.rest.methods().editMessage(content, @channel_id, @id)

  delete: () -> #CAUTION
    @client.rest.methods().deleteMessage(@channel_id, @id)

  pin: () ->
    @client.rest.methods().pinMessage(@channel_id, @id)

  deletePin: () -> #CAUTION
    @client.rest.methods().deletePinnedMessage(@channel_id, @id)

module.exports = Message