u = require('../utils.coffee')
utils = new u()
Constants = require './../constants'

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

  modify: (options) ->
    if !options then new Error("Expected type Object for parameter options, got: "+typeof options)
    if options.name
      if typeof options.name != "String" then new Error("Expected type String for option name, got: "+typeof options.name)
      if options.name == "" then new Error("No value given for String: name")
    if options.position
      if typeof options.position != "Number" then new Error("Expected type Number for option position, got: "+typeof option.position)
    if options.topic
      if typeof options.topic != "String" then new Error("Expected type String for option topic, got: "+typeof options.topic)
    @client.rest.methods().modifyTextChannel(@id, options)

  setChannelName: (name) ->
    if !name then new Error("Expected type String for parameter name, got: "+typeof name)
    if name == "" then new Error("No value given for String: name")
    name = name.replace(/\s/gmi,"").toLowerCase()
    @client.rest.methods().modifyTextChannel(@id, {name: name})

  setPosition: (pos) ->
    if !pos then pos = 0
    @client.rest.methods().modifyTextChannel(@id, {position: pos})

  setTopic: (topic) ->
    if !topic then topic = ""
    @client.rest.methods().modifyTextChannel(@id, {topic: topic})

  delete: () -> #CAUTION
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
    return @client.rest.methods().getMessage(message_id)

  deleteMessage: (message_id) ->
    if !message_id then new Error("Expected type String for parameter message_id, got: "+typeof message_id)
    if message_id == "" then new Error("No value given for String: message_id")
    @client.rest.methods().deleteMessage(@id, message_id)

  deleteMessages: (message_ids) ->
    if !message_ids || typeof message_ids != "Array" then new Error("Expected type Array for parameter message_ids, got: "+typeof message_ids)
    if message_ids.length < 2 then new Error("No values given for Array: message_id")
    if message_ids.length > 100 then new Error("Too many values given for Array: message_id")
    @client.rest.methods().bulkDeleteMessages(@id, message_ids)

  setRAWPermissions: (overwrite_id, allow, deny, type) -> #overwrite_id is a user_id for type user and role_id for type role
    if typeof overwrite_id != "String" then new Error("Expected type String for parameter overwrite_id, got: "+typeof overwrite_id)
    if typeof allow != "Number" then new Error("Expected type Number for parameter allow, got: "+typeof allow)
    if typeof deny != "Number" then new Error("Expected type Number for parameter deny, got: "+typeof deny)
    if typeof type != "String" then new Error("Expected type String for parameter type, got: "+typeof type)
    options = {allow: allow, deny: deny, type: type}
    @client.rest.methods().setChannelPermissions(@id, overwrite_id, options)

  setPermissions: (overwrite_id, allow = [], deny = [], type) ->
    if typeof overwrite_id != "String" then new Error("Expected type String for parameter overwrite_id, got: "+typeof overwrite_id)
    if typeof allow != "Array" then new Error("Expected type Array for parameter allow, got: "+typeof allow)
    if typeof deny != "Array" then new Error("Expected type Array for parameter deny, got: "+typeof deny)
    if typeof type != "String" then new Error("Expected type String for parameter type, got: "+typeof type)
    totalAllow = 0
    for a in allow
      totalAllow |= Constants.permissions[a]
    totalDeny = 0
    for d in deny
      totalDeny |= Constants.permissions[d]
    options = {allow: totalAllow, deny: totalDeny, type: type}
    @client.rest.methods().setChannelPermissions(@id, overwrite_id, options)

  deletePermission: (overwrite_id) ->
    if typeof overwrite_id != "String" then new Error("Expected type String for parameter overwrite_id, got: "+typeof overwrite_id)
    @client.rest.methods().deleteChannelPermissions(@id, overwrite_id)

  getInvites: () ->
    return @client.rest.methods().getChannelInvites(@id)

  createInvite: (max_age = 86400, max_uses = 0, temporary = false, unique = false) ->
    return @client.rest.methods().createChannelInvite(@id, max_age, max_uses, temporary, unique)

  triggerTyping: () ->
    @client.rest.methods().triggerTypingIndicator(@id)


module.exports = TextChannel