u = require('../utils.coffee')
utils = new u()
util = require 'util'
voiceConnection = require '../voice/voiceConnection'
TextChannel = require '../resources/TextChannel'
VoiceChannel = require '../resources/VoiceChannel'
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
      when 'TYPING_START' then utils.debug("<@"+data.d.user_id+"> is typing")
      when 'PRESENCE_UPDATE' then @discordClient.emit("status",data.d.user.id,data.d.status,data.d.game,data.d)
      when 'CHANNEL_UPDATE' then utils.debug("CHANNEL_UPDATE event caught")
      when 'VOICE_STATE_UPDATE' then utils.debug("VOICE_STATE_UPDATE event caught")
      when 'VOICE_SERVER_UPDATE' then @handleVoiceConnection(data)
      else
        utils.debug("Unhandled Dispatch t: "+data.t, "warn")

  handleReady: (data) ->
    utils.debug("Gateway Ready, Guilds: 0 Available / "+data.d.guilds.length+" Unavailable", "info")
    @discordClient.internals.session_id = data.d.session_id
    @discordClient.internals.user_id = data.d.user.id
    self = @
    # Setup gateway heartbeat
    @clientConnection.gatewayHeartbeat = setInterval(() ->
      hbPackage = {
        "op": 1
        "d": self.discordClient.internals.sequence
      }
      self.discordClient.internals.gatewayPing = new Date().getTime()
      self.discordClient.gatewayWS.send(JSON.stringify(hbPackage))
    ,@clientConnection.HEARTBEAT_INTERVAL)
    @discordClient.internals.connected = true
    @discordClient.emit("ready", data.d)
    #console.log(util.inspect(data, false, null))

  handleGuildCreate: (data) -> #fired when bot lazy loads available guilds and joins a new guild
    for i, channel of data.d.channels
      channel.guild_id = data.d.id
      if channel.type == 2
        @discordClient.internals.channels[channel.id] = new VoiceChannel(@discordClient, channel)
        data.d.channels[i] = new VoiceChannel(@discordClient, channel)
      else
        @discordClient.internals.channels[channel.id] = new TextChannel(@discordClient, channel)
        data.d.channels[i] = new TextChannel(@discordClient, channel)
    @discordClient.internals.servers[data.d.id] = data.d
    @discordClient.internals.servers[data.d.id].voice = {}
    thisServer = @discordClient.internals.servers[data.d.id]
    #console.log thisServer.channels
    utils.debug("Joined Guild: "+thisServer.name+" ("+thisServer.presences.length+" online / "+(parseInt(thisServer.member_count)-thisServer.presences.length)+" offline)","info")

  handleMessageCreate: (data) ->
    #console.log data.d
    msg = data.d
    if @discordClient.internals.channels[data.d.channel_id]
      @discordClient.emit("message",new Message(@discordClient, msg))
    else
      utils.debug("Message Create Event Occurred in unknown channel","warn")

  handleVoiceConnection: (data) -> #bot has connected to voice channel
    utils.debug("Joined Voice Channel","info")
    @discordClient.internals.servers[data.d.guild_id].voice = new voiceConnection(@discordClient)
    @discordClient.internals.servers[data.d.guild_id].voice.connect(data.d)

module.exports = Dispatcher
