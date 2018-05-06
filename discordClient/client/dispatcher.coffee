u = require('../utils.coffee')
utils = new u()
util = require 'util'
Constants = require '../constants'
voiceHandler = require '../voice/voiceHandler'
TextChannel = require '../resources/TextChannel'
VoiceChannel = require '../resources/VoiceChannel'
VoiceConnection = require '../resources/VoiceConnection'
DirectMessageChannel = require '../resources/DirectMessageChannel'
Message = require '../resources/Message'

###
# In charge of parsing op 0 packages and turning them into relevant EventEmitter events
###
class Dispatcher
  constructor: (@discordClient, @clientConnection) ->

  parseDispatch: (data) ->
    @discordClient.internals.sequence = data.s
    switch data.t
      when 'READY' then @handleReady(data)
      when 'GUILD_CREATE' then @handleGuildCreate(data)
      when 'MESSAGE_CREATE' then @handleMessageCreate(data)
      when 'MESSAGE_DELETE' then @handleMessageDelete(data)
      when 'MESSAGE_REACTION_ADD' then @handleMessageReactionAdd(data)
      when 'MESSAGE_REACTION_REMOVE' then @handleMessageReactionRemove(data)
      when 'TYPING_START' then utils.debug("<@"+data.d.user_id+"> is typing")
      when 'PRESENCE_UPDATE' then @discordClient.emit("status",data.d.user.id,data.d.status,data.d.game,data.d)
      when 'CHANNEL_UPDATE' then utils.debug("CHANNEL_UPDATE event caught")
      when 'VOICE_STATE_UPDATE' then @handleVoiceStateUpdate(data)
      when 'VOICE_SERVER_UPDATE' then @handleVoiceConnection(data)
      when 'RESUMED' then @handleResume(data)
      else
        utils.debug("Unhandled Dispatch t: "+data.t, "warn")

  handleReady: (data) ->
    utils.debug("Gateway Ready, Guilds: 0 Available / "+data.d.guilds.length+" Unavailable", "info")
    @discordClient.internals.session_id = data.d.session_id
    @discordClient.internals.user_id = data.d.user.id
    self = @
    @connected = true
    for dm in data.d.private_channels
      @discordClient.channels[dm.id] = new DirectMessageChannel(@discordClient, dm) #TODO might have changed, so might have to use extra endpoint call
    @discordClient.emit("ready", data.d)

  handleGuildCreate: (data) -> #fired when bot lazy loads available guilds and joins a new guild
    for i, channel of data.d.channels
      channel.guild_id = data.d.id
      if channel.type == Constants.channelTypes.voice
        @discordClient.channels[channel.id] = new VoiceChannel(@discordClient, channel)
        data.d.channels[i] = new VoiceChannel(@discordClient, channel)
      else if channel.type == Constants.channelTypes.text
        @discordClient.channels[channel.id] = new TextChannel(@discordClient, channel)
        data.d.channels[i] = new TextChannel(@discordClient, channel)
      else if channel.type == Constants.channelTypes.channelCategory
        utils.debug("Channel Category Registered: "+channel.name)
      else
        utils.debug("Unknown channel type: "+channel.type,"warn")
    @discordClient.guilds[data.d.id] = data.d
    @discordClient.guilds[data.d.id].voice = {}
    thisServer = @discordClient.guilds[data.d.id]
    #console.log thisServer.channels
    @discordClient.emit("guildCreate", thisServer)
    utils.debug("Joined Guild: "+thisServer.name+" ("+thisServer.presences.length+" online / "+(parseInt(thisServer.member_count)-thisServer.presences.length)+" offline)","info")

  handleMessageReactionAdd: (data) ->
    #console.log data.d
    msg = data.d
    if @discordClient.channels[data.d.channel_id]
      @discordClient.emit("reaction", "add", msg)
    else
      utils.debug("Message Reaction Add Event Occurred in unknown channel","warn")

  handleMessageReactionRemove: (data) ->
    #console.log data.d
    msg = data.d
    if @discordClient.channels[data.d.channel_id]
      @discordClient.emit("reaction", "remove", msg)
    else
      utils.debug("Message Reaction Remove Event Occurred in unknown channel","warn")

  handleMessageCreate: (data) ->
    #console.log data.d
    msg = data.d
    if @discordClient.channels[data.d.channel_id]
      @discordClient.emit("message",new Message(@discordClient, msg))
    else
      utils.debug("Message Create Event Occurred in unknown channel","warn")

  handleMessageDelete: (data) ->
    #console.log data.d
    msg = data.d
    channel = @discordClient.channels[data.d.channel_id]
    if channel
      @discordClient.emit("messageDelete", data.d.id, channel)
    else
      utils.debug("Message DeleteEvent Occurred in unknown channel","warn")

  handleVoiceStateUpdate: (data) ->
    utils.debug("VOICE_STATE_UPDATE event caught")
    console.log data
    if data.d
      if data.d.channel_id
        data.d.channel = @discordClient.channels[data.d.channel_id]
        if @discordClient.voiceConnections[data.d.guild_id]
          @discordClient.voiceConnections[data.d.guild_id].channel_id = data.d.channel_id
          @discordClient.voiceConnections[data.d.guild_id].channel_name = data.d.channel.name
      @discordClient.emit("voiceChannelUpdate", data.d)

  handleVoiceConnection: (data) -> #bot has connected to voice channel
    utils.debug("Joined Voice Channel","info")
    @discordClient.voiceHandlers[data.d.guild_id] = new voiceHandler(@discordClient)
    @discordClient.voiceHandlers[data.d.guild_id].connect(data.d)
    @discordClient.emit("VOICE_STATE_UPDATE",new VoiceConnection(@discordClient, @discordClient.voiceHandlers[data.d.guild_id]))

  handleResume: (data) ->
    console.log data
    utils.debug("Connection Resumed","info")
    @discordClient.internals.resuming = false
    @discordClient.internals.connection_retry_count = 0
    @connected = true

module.exports = Dispatcher
