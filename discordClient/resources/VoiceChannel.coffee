u = require('../utils.coffee')
utils = new u()

class VoiceChannel

  constructor: (@client, channel) ->
    @id = channel.id
    @guild_id = channel.guild_id
    @name = channel.name
    @type = channel.type
    @position = channel.position
    @is_private = channel.is_private
    @permission_overwrites = channel.permission_overwrites
    @bitrate = channel.bitrate
    @user_limit = channel.user_limit

  join: (mute = false, deaf = false) ->
    joinVoicePackage = {
      "op": 4,
      "d": {
        "guild_id": @guild_id,
        "channel_id": @id,
        "self_mute": mute,
        "self_deaf": deaf
      }
    }
    self = @
    return new Promise((resolve, reject) ->
      self.client.gatewayWS.send(JSON.stringify(joinVoicePackage))
      self.client.on("VOICE_STATE_UPDATE", (voiceConnection) ->
        voiceConnection.channel_id = self.id
        voiceConnection.channel_name = self.name
        self.client.voiceConnections[self.guild_id] = voiceConnection
        resolve(voiceConnection)
      )
    )

  leave: () ->
    leaveVoicePackage = {
      "op": 4,
      "d": {
        "guild_id": @guild_id,
        "channel_id": null,
        "self_mute": false,
        "self_deaf": false
      }
    }
    @client.gatewayWS.send(JSON.stringify(leaveVoicePackage))

  modify: (options) ->
    if !options then new Error("Expected type Object for parameter options, got: "+typeof options)
    if options.name
      if typeof options.name != "String" then new Error("Expected type String for option name, got: "+typeof options.name)
      if options.name == "" then new Error("No value given for String: name")
    if options.position
      if typeof options.position != "Number" then new Error("Expected type Number for option position, got: "+typeof option.position)
    if options.bitrate
      if typeof options.bitrate != "Number" then new Error("Expected type Number for option bitrate, got: "+typeof options.bitrate)
    if options.user_limit
      if typeof options.user_limit != "Number" then new Error("Expected type Number for option user_limit, got: "+typeof options.user_limit)
    @client.rest.methods().modifyVoiceChannel(@id, options)

  setChannelName: (name) ->
    if !name then new Error("Expected type String for parameter name, got: "+typeof name)
    if name == "" then new Error("No value given for String: name")
    name = name.replace(/\s/gmi,"").toLowerCase()
    @client.rest.methods().modifyVoiceChannel(@id, {name: name})

  setPosition: (pos) ->
    if !pos then pos = 0
    @client.rest.methods().modifyTextChannel(@id, {position: pos})

  setBitrate: (bitrate) ->
    if !bitrate then bitrate = 64000
    @client.rest.methods().modifyTextChannel(@id, {bitrate: bitrate})

  setUserLimit: (user_limit) ->
    if !user_limit then user_limit = 0
    @client.rest.methods().modifyTextChannel(@id, {user_limit: user_limit})

  delete: () -> #CAUTION
    @client.rest.methods().deleteChannel(@id)

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

module.exports = VoiceChannel