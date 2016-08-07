u = require('../utils.coffee')
utils = new u()
ws = require 'ws'
zlib = require 'zlib'

class VoiceConnection

  constructor: (@discordClient) ->
    utils.debug("New Voice Connection Started")

  connect: (params) ->
    self = @
    if @discordClient.internals.servers[params.guild_id].voice
      serverVoice = @discordClient.internals.servers[params.guild_id].voice
      serverVoice = {
        "token": params.token,
        "guild_id": params.guild_id,
        "endpoint": params.endpoint
        "user_id": @discordClient.internals.user_id
        "session_id": @discordClient.internals.session_id
        "vws": null
      }
      utils.debug("Generating new voice websocket connection")
      serverVoice.vws = new ws("wss://"+serverVoice.endpoint.split(":")[0])
      serverVoice.vws.once('open', () -> self.voiceGatewayOpen(serverVoice.guild_id))
      serverVoice.vws.once('close', () -> self.voiceGatewayClose())
      serverVoice.vws.once('error', (err) -> self.voiceGatewayError(err))
      serverVoice.vws.on('message', (msg, flags) -> self.voiceGatewayMessage(msg, flags, serverVoice.guild_id))
    else
      utils.debug("Unknown Server?","error")

  voiceGatewayOpen: (guild_id) ->
    utils.debug("Voice gateway server is open")
    #send identity package
    serverVoice = @discordClient.internals.servers[guild_id].voice
    idpackage = {
      "op": 0
      "d": {
        "server_id": guild_id,
        "user_id": @discordClient.internals.user_id,
        "session_id": @discordClient.internals.session_id,
        "token": serverVoice.token
      }
    }
    serverVoice.vws.send(JSON.stringify(idpackage))

  voiceGatewayClose: () ->
    utils.debug("Voice gateway server is CLOSED","warn")

  voiceGatewayError: (err) ->
    utils.debug("Voice gateway server encountered an error: "+err.toString(),"error")

  voiceGatewayMessage: (data, flags, guild_id) ->
    msg = if flags.binary then JSON.parse(zlib.inflateSync(data).toString()) else JSON.parse(data)
    console.log msg
    #go through ops to establish UDP connection

module.exports = VoiceConnection
