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

  deleteUsersReaction: (emoji, userId) ->

  deleteAllReactions: () -> #CAUTION

  edit: (content) ->

  delete: () -> #CAUTION

  pin: () ->

  deletePin: () -> #CAUTION

module.exports = Message