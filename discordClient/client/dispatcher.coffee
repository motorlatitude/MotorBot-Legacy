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
    @discordClient.utils.debug("[GATEWAYSOCKET] <~ ["+@discordClient.internals.gateway.toUpperCase()+"]: Received "+data.t+" Payload");
    switch data.t
      when 'READY' then @handleReady(data)
      when 'CHANNEL_CREATE' then @handleChannelCreate(data)
      when 'CHANNEL_UPDATE' then @handleChannelUpdate(data)
      when 'CHANNEL_DELETE' then @handleChannelDelete(data)
      when 'CHANNEL_PINS_UPDATE' then @handleChannelPinsUpdate(data)
      when 'GUILD_CREATE' then @handleGuildCreate(data)
      when 'MESSAGE_CREATE' then @handleMessageCreate(data)
      when 'MESSAGE_UPDATE' then @handleMessageUpdate(data)
      when 'MESSAGE_DELETE' then @handleMessageDelete(data)
      when 'MESSAGE_REACTION_ADD' then @handleMessageReactionAdd(data)
      when 'MESSAGE_REACTION_REMOVE' then @handleMessageReactionRemove(data)
      when 'TYPING_START' then @handleTypingStart(data)
      when 'PRESENCE_UPDATE' then @discordClient.emit("status",data.d.user.id,data.d.status,data.d.game,data.d)
      when 'USER_UPDATE' then @handleUserUpdate(data)
      when 'VOICE_STATE_UPDATE' then @handleVoiceStateUpdate(data)
      when 'VOICE_SERVER_UPDATE' then @handleVoiceConnection(data)
      when 'RESUMED' then @handleResume(data)
      else
        @discordClient.utils.debug("Unhandled Dispatch t: "+data.t, "warn")

  handleReady: (data) ->
    @discordClient.utils.debug("Gateway Ready, Guilds: 0 Available / "+data.d.guilds.length+" Unavailable", "info")
    @discordClient.internals.session_id = data.d.session_id
    @discordClient.internals.user_id = data.d.user.id
    self = @
    @connected = true
    for dm in data.d.private_channels
      @discordClient.channels[dm.id] = new DirectMessageChannel(@discordClient, dm) #TODO might have changed, so might have to use extra endpoint call
    @discordClient.emit("ready", data.d)

  handleChannelCreate: (data) ->
    #console.log data.d
    if data.d.type == Constants.channelTypes.text
      @discordClient.channels[data.d.id] = new TextChannel(@discordClient, data.d)
      @discordClient.emit("channelCreate", Constants.channelTypes.text, new TextChannel(@discordClient, data.d))
    else if data.d.type == Constants.channelTypes.DirectMessage
      @discordClient.channels[data.d.id] = new DirectMessageChannel(@discordClient, data.d)
      @discordClient.emit("channelCreate", Constants.channelTypes.DirectMessage, new DirectMessageChannel(@discordClient, data.d))
    else if data.d.type == Constants.channelTypes.voice
      @discordClient.channels[data.d.id] = new VoiceChannel(@discordClient, data.d)
      @discordClient.emit("channelCreate", Constants.channelTypes.voice, new VoiceChannel(@discordClient, data.d))
    else if data.d.type == Constants.channelTypes.groupDirectMessage
      #TODO check if the GroupDM is similar or the same as DM
      @discordClient.channels[data.d.id] = new DirectMessageChannel(@discordClient, data.d)
      @discordClient.emit("channelCreate", Constants.channelTypes.groupDirectMessage, new DirectMessageChannel(@discordClient, data.d))
    else if data.d.type == Constants.channelTypes.channelCategory
      #@discordClient.emit("channelCreate", Constants.channelTypes.channelCategory, new DirectMessageChannel(@discordClient, data.d))
    else
      @discordClient.utils.debug("Channel Create Event Occurred with an unknown channel type","warn")

  handleChannelUpdate: (data) ->
    #console.log data.d
    if data.d.type == Constants.channelTypes.text
      @discordClient.emit("channelUpdate", Constants.channelTypes.text, new TextChannel(@discordClient, data.d))
    else if data.d.type == Constants.channelTypes.DirectMessage
      @discordClient.emit("channelUpdate", Constants.channelTypes.DirectMessage, new DirectMessageChannel(@discordClient, data.d))
    else if data.d.type == Constants.channelTypes.voice
      @discordClient.emit("channelUpdate", Constants.channelTypes.voice, new VoiceChannel(@discordClient, data.d))
    else if data.d.type == Constants.channelTypes.groupDirectMessage
      #TODO check if the GroupDM is similar or the same as DM
      @discordClient.emit("channelUpdate", Constants.channelTypes.groupDirectMessage, new DirectMessageChannel(@discordClient, data.d))
    else if data.d.type == Constants.channelTypes.channelCategory
      #@discordClient.emit("channelCreate", Constants.channelTypes.channelCategory, new DirectMessageChannel(@discordClient, data.d))
    else
      @discordClient.utils.debug("Channel Update Event Occurred with an unknown channel type","warn")

  handleChannelDelete: (data) ->
    #console.log data.d
    if data.d.type == Constants.channelTypes.text
      if @discordClient.channels[data.d.id] then delete @discordClient.channels[data.d.id]
      @discordClient.emit("channelDelete", Constants.channelTypes.text, new TextChannel(@discordClient, data.d))
    else if data.d.type == Constants.channelTypes.DirectMessage
      if @discordClient.channels[data.d.id] then delete @discordClient.channels[data.d.id]
      @discordClient.emit("channelDelete", Constants.channelTypes.DirectMessage, new DirectMessageChannel(@discordClient, data.d))
    else if data.d.type == Constants.channelTypes.voice
      if @discordClient.channels[data.d.id] then delete @discordClient.channels[data.d.id]
      @discordClient.emit("channelDelete", Constants.channelTypes.voice, new VoiceChannel(@discordClient, data.d))
    else if data.d.type == Constants.channelTypes.groupDirectMessage
      #TODO check if the GroupDM is similar or the same as DM
      if @discordClient.channels[data.d.id] then delete @discordClient.channels[data.d.id]
      @discordClient.emit("channelDelete", Constants.channelTypes.groupDirectMessage, new DirectMessageChannel(@discordClient, data.d))
    else if data.d.type == Constants.channelTypes.channelCategory
      if @discordClient.channels[data.d.id] then delete @discordClient.channels[data.d.id]
      #@discordClient.emit("channelCreate", Constants.channelTypes.channelCategory, new DirectMessageChannel(@discordClient, data.d))
    else
      @discordClient.utils.debug("Channel Delete Event Occurred with an unknown channel type","warn")
      @discordClient.utils.debug("Channel has not been removed from discordClient channel object")

  handleChannelPinsUpdate: (data) ->
    if @discordClient.channels[data.d.channel_id]
      @discordClient.emit("channelPinsUpdate", data.d)
    else
      @discordClient.utils.debug("Channel Pins Update Event Occurred in unknown channel","warn")

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
        @discordClient.utils.debug("Channel Category Registered: "+channel.name)
      else
        @discordClient.utils.debug("Unknown channel type: "+channel.type,"warn")
    for i, user of data.d.members
      u = user.user
      @discordClient.utils.debug("Registering User "+u.username+"#"+u.discriminator)
      @discordClient.users[u.id] = u
    @discordClient.guilds[data.d.id] = data.d
    @discordClient.guilds[data.d.id].voice = {}
    thisServer = @discordClient.guilds[data.d.id]
    #console.log thisServer.channels
    @discordClient.emit("guildCreate", thisServer)
    @discordClient.utils.debug("Joined Guild: "+thisServer.name+" ("+thisServer.presences.length+" online / "+(parseInt(thisServer.member_count)-thisServer.presences.length)+" offline)","info")

  handleMessageReactionAdd: (data) ->
    #console.log data.d
    msg = data.d
    if @discordClient.channels[data.d.channel_id]
      @discordClient.emit("reaction", "add", msg)
    else
      @discordClient.utils.debug("Message Reaction Add Event Occurred in unknown channel","warn")

  handleMessageReactionRemove: (data) ->
    #console.log data.d
    msg = data.d
    if @discordClient.channels[data.d.channel_id]
      @discordClient.emit("reaction", "remove", msg)
    else
      @discordClient.utils.debug("Message Reaction Remove Event Occurred in unknown channel","warn")

  handleMessageCreate: (data) ->
    #console.log data.d
    msg = data.d
    if @discordClient.channels[data.d.channel_id]
      @discordClient.emit("message",new Message(@discordClient, msg))
    else
      @discordClient.utils.debug("Message Create Event Occurred in unknown channel","warn")

  handleMessageUpdate: (data) ->
    #console.log data.d
    msg = data.d
    if @discordClient.channels[data.d.channel_id]
      @discordClient.emit("messageUpdate",new Message(@discordClient, msg))
    else
      @discordClient.utils.debug("Message Update Event Occurred in unknown channel","warn")

  handleMessageDelete: (data) ->
    #console.log data.d
    msg = data.d
    channel = @discordClient.channels[data.d.channel_id]
    if channel
      @discordClient.emit("messageDelete", data.d.id, channel)
    else
      @discordClient.utils.debug("Message Delete Event Occurred in unknown channel","warn")

  handleTypingStart: (data) ->
    #console.log data.d
    channel = @discordClient.channels[data.d.channel_id]
    if channel
      @discordClient.emit("typingStart", data.d.user_id, channel, data.d.timestamp)
    else
      @discordClient.utils.debug("Typing Start Event Occurred in unknown channel","warn")

  handleUserUpdate: (data) ->
    user = data.d
    if user.id
      @discordClient.emit("userUpdate", user.id, user.username, data.d)
    else
      @discordClient.utils.debug("UserUpdate event occurred for an unknown user")

  handleVoiceStateUpdate: (data) ->
    @discordClient.utils.debug("VOICE_STATE_UPDATE event caught")
    #console.log data
    if data.d
      if data.d.channel_id
        data.d.channel = @discordClient.channels[data.d.channel_id]
        if @discordClient.voiceConnections[data.d.guild_id]
          @discordClient.voiceConnections[data.d.guild_id].channel_id = data.d.channel_id
          @discordClient.voiceConnections[data.d.guild_id].channel_name = data.d.channel.name
      @discordClient.emit("voiceChannelUpdate", data.d)

  handleVoiceConnection: (data) -> #bot has connected to voice channel
    @discordClient.utils.debug("Joined Voice Channel","info")
    @discordClient.voiceHandlers[data.d.guild_id] = new voiceHandler(@discordClient)
    @discordClient.voiceHandlers[data.d.guild_id].connect(data.d)
    @discordClient.emit("VOICE_STATE_UPDATE",new VoiceConnection(@discordClient, @discordClient.voiceHandlers[data.d.guild_id]))

  handleResume: (data) ->
    @discordClient.utils.debug("Connection Resumed","info")
    @discordClient.internals.resuming = false
    @discordClient.internals.connection_retry_count = 0
    @connected = true

module.exports = Dispatcher
