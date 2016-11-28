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
    @client.gatewayWS.send(JSON.stringify(joinVoicePackage))

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

  delete: () -> #CAUTION

  setPermissions: (allow, deny, type) ->

  deletePermission: (overwriteId) ->

  getInvites: () ->

  createInvite: (max_age, max_uses, temporary, unique) ->

module.exports = VoiceChannel