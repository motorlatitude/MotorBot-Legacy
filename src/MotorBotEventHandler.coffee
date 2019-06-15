
ReadyEvent = require './events/ReadyEvent.coffee'
GuildCreateEvent = require './events/GuildCreateEvent.coffee'
VoiceUpdateEvent = require './events/VoiceUpdateEvent.coffee'
VoiceChannelUpdateEvent = require './events/VoiceChannelUpdateEvent.coffee'
StatusEvent = require './events/StatusEvent.coffee'
ReactionEvent = require './events/ReactionEvent.coffee'
MessageEvent = require './events/MessageEvent.coffee'

class MotorBotEventHandler

  constructor: (@App, @Logger) ->


  RegisterEventListener: (@client) ->
    self = @

    @client.on("ready", () ->
      new ReadyEvent(self.client, self.Logger)
    )
    @client.on("guildCreate", (guild) ->
      new GuildCreateEvent(self.client, self.Logger, guild)
    )
    @client.on("voiceUpdate_Speaking", (data) ->
      new VoiceUpdateEvent(self.App, self.client, self.Logger, "speaking", data)
    )
    @client.on("voiceChannelUpdate", (data) ->
      new VoiceChannelUpdateEvent(self.App, self.client, self.Logger, data)
    )
    @client.on("status", (user_id,status,game,extra_info) ->
      new StatusEvent(self.App, self.client, self.Logger, user_id, status, game, extra_info)
    )
    @client.on("reaction", (type, data) ->
      new ReactionEvent(self.App, self.client, self.Logger, type, data)
    )
    @client.on("message", (msg) ->
      new MessageEvent(self.App, self.client, self.Logger, msg)
    )

module.exports = MotorBotEventHandler