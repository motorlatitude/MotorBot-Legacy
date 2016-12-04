u = require('../utils.coffee')
utils = new u()
Constants = require './../constants'

class DirectMessageChannel

  constructor: (@client, channel) ->
    @id = channel.id
    @type = channel.type
    @is_private = channel.is_private || true
    @last_message_id = channel.last_message_id
    @recipient = channel.recipient

  sendMessage: (content, options) ->
    if !content then new Error("Expected type String for parameter content, got: "+typeof content)
    if content == "" then new Error("No value given for String: content")
    @client.rest.methods().createMessage(content, @id, options)

  reply: (content, options) ->
    if !content then new Error("Expected type String for parameter content, got: "+typeof content)
    if content == "" then new Error("No value given for String: content")
    @sendMessage(content, options)

  sendMessageWithFile: (content, filepath, filename, options) ->
    if !content then new Error("Expected type String for parameter content, got: "+typeof content)
    if !filepath then new Error("Expected type String for parameter filepath, got: "+typeof content)
    if filepath == "" then new Error("No value given for String: filepath")
    @client.rest.methods().uploadFile(content, filepath, filename, options)

  close: () ->
    @client.rest.methods().deleteChannel(@id)

  getMessages: (options) ->
    i = 0
    if options
      if options.around
        if typeof options.around != "String" then new Error("Expected type String for parameter around, got: "+typeof options.around)
        i++
      if options.before
        if typeof options.before != "String" then new Error("Expected type String for parameter before, got: "+typeof options.before)
        i++
      if options.after
        if typeof options.after != "String" then new Error("Expected type String for parameter after, got: "+typeof options.after)
        i++
      if options.limit
        if typeof options.limit != "Number" then new Error("Expected type Number for parameter limit, got: "+typeof options.limit)
    if i > 1 then new Error("Only one option can be passed, either around, before or after")
    return @client.rest.methods().getMessages(@id, options)

  getPinnedMessages: () ->
    return @client.rest.methods().getPinnedMessages(@id)

  getMessage: (message_id) ->
    if !message_id then new Error("Expected type String for parameter message_id, got: "+typeof message_id)
    if message_id == "" then new Error("No value given for String: message_id")
    return @client.rest.methods().getMessage(@id, message_id)

  deleteMessage: (message_id) ->
    if !message_id then new Error("Expected type String for parameter message_id, got: "+typeof message_id)
    if message_id == "" then new Error("No value given for String: message_id")
    @client.rest.methods().deleteMessage(@id, message_id)

  deleteMessages: (message_ids) ->
    if !message_ids || typeof message_ids != "Array" then new Error("Expected type Array for parameter message_ids, got: "+typeof message_ids)
    if message_ids.length < 2 then new Error("No values given for Array: message_id")
    if message_ids.length > 100 then new Error("Too many values given for Array: message_id")
    @client.rest.methods().bulkDeleteMessages(@id, message_ids)

  triggerTyping: () ->
    @client.rest.methods().triggerTypingIndicator(@id)

  addRecipient: (access_token, user_id, nick = "") ->
    if typeof access_token != "String" then new Error("Expected type String for parameter access_id, got: "+typeof access_token)
    if access_token == "" then new Error("No value given for String: access_token")
    if typeof user_id != "String" then new Error("Expected type String for parameter user_id, got: "+typeof user_id)
    @client.rest.methods().addRecipient(@id, user_id, {access_token: access_token, nick: nick})

  removeRecipient: (user_id) ->
    if typeof user_id != "String" then new Error("Expected type String for parameter user_id, got: "+typeof user_id)
    @client.rest.methods().removeRecipient(@id, user_id)

module.exports = DirectMessageChannel