u = require('../utils.coffee')
utils = new u()
util = require 'util'
voiceConnection = require '../voice/voiceConnection.coffee'

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
        console.log data

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

  handleGuildCreate: (data) -> #fired when bot lazy loads available guilds and join a new guild
    @discordClient.internals.servers[data.d.id] = data.d
    @discordClient.internals.servers[data.d.id].voice = {}
    thisServer = @discordClient.internals.servers[data.d.id]
    utils.debug("Joined Guild: "+thisServer.name+" ("+thisServer.presences.length+" online / "+(parseInt(thisServer.member_count)-thisServer.presences.length)+" offline)","info")

  handleMessageCreate: (data) ->
    @discordClient.emit("message",data.d.content,data.d.channel_id,data.d.author.id,data.d)

  handleVoiceConnection: (data) ->
    #start dealing with voice stuff
    utils.debug("I've joined a voice channel :D")
    vc = new voiceConnection(@discordClient)
    vc.connect(data.d)


module.exports = Dispatcher