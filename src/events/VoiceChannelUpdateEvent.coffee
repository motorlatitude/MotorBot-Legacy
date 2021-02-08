req = require 'request'
keys = require './../../keys.json'

class VoiceChannelUpdateEvent

  constructor: (@App, @Client, @Logger, data) ->
    self = @
    if data.user_id == '169554882674556930'
      if data.channel
        self.App.WebSocket.broadcast(JSON.stringify({type: "VOICE_UPDATE", d:{status:"JOIN", channel: data.channel.name, channel_id: data.channel.id, channel_obj: data, guild_id: data.guild_id}}, (key, value) ->
          if key == "client"
            return undefined
          else
            return value
        ))
      else
        delete self.App.Client.voiceConnections[data.guild_id]
        self.App.WebSocket.broadcast(JSON.stringify({type: "VOICE_UPDATE", d:{status:"LEAVE", channel: undefined, channel_id: undefined, channel_obj: data, guild_id: data.guild_id}}, (key, value) ->
          if key == "client"
            return undefined
          else
            return value
        ))
    d = new Date()
    time = "`["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"]` "
    if data.channel
      if self.App.VoiceStates[data.user_id]
        if self.App.VoiceStates[data.user_id].channel
          #previously in channel hence channel voice state change
          #voice state trigger
          if data.deaf && !self.App.VoiceStates[data.user_id].deaf
            #deafened from server
            self.Client.channels["432351112616738837"].sendMessage(time+"<@"+data.user_id+"> was server deafened in the `"+data.channel.name+"` voice channel")
          if data.mute && !self.App.VoiceStates[data.user_id].mute
            #muted from server
            self.Client.channels["432351112616738837"].sendMessage(time+"<@"+data.user_id+"> was server muted in the `"+data.channel.name+"` voice channel")
          if data.self_deaf && !self.App.VoiceStates[data.user_id].self_deaf
            #user has deafened himself
            self.Client.channels["432351112616738837"].sendMessage(time+"<@"+data.user_id+"> has deafened them self in the `"+data.channel.name+"` voice channel")
          if data.self_mute && !self.App.VoiceStates[data.user_id].self_mute
            #user has muted himself
            self.Client.channels["432351112616738837"].sendMessage(time+"<@"+data.user_id+"> has muted them self in the `"+data.channel.name+"` voice channel")
          #voice state trigger reverse
          if !data.deaf && self.App.VoiceStates[data.user_id].deaf
            #undeafened from server
            self.Client.channels["432351112616738837"].sendMessage(time+"<@"+data.user_id+"> is no longer server deafened in the `"+data.channel.name+"` voice channel")
          if !data.mute && self.App.VoiceStates[data.user_id].mute
            #unmuted from server
            self.Client.channels["432351112616738837"].sendMessage(time+"<@"+data.user_id+"> is no longer server muted in the `"+data.channel.name+"` voice channel")
          if !data.self_deaf && self.App.VoiceStates[data.user_id].self_deaf
            #user has undeafened himself
            self.Client.channels["432351112616738837"].sendMessage(time+"<@"+data.user_id+"> is no longer deafened in the `"+data.channel.name+"` voice channel")
          if !data.self_mute && self.App.VoiceStates[data.user_id].self_mute
            #user has unmuted himself
            self.Client.channels["432351112616738837"].sendMessage(time+"<@"+data.user_id+"> is no longer muted in the `"+data.channel.name+"` voice channel")
        else
          #newly joined
          self.SendVoiceStateEventLog(data, "joined")
      else
        self.SendVoiceStateEventLog(data, "joined")
    else
      self.SendVoiceStateEventLog(data, "left")
    self.App.VoiceStates[data.user_id] = data

  SendVoiceStateEventLog: (data, voice_status) ->
    self = @
    self.Client.channels["432351112616738837"].sendMessageWithFile("", req.get({
      url: keys.baseURL+'/api/DiscordWebsocketEvent/capture?api_key=caf07b8b-366e-44ab-9bda-623f94a9c2df',
      json: true
      body: {
        "PresenceUpdateData": {
          "type": "VoiceUpdate",
          "id": data.user_id,
          "avatar": self.Client.users[data.user_id].avatar,
          "user": self.Client.users[data.user_id].username,
          "discriminator": self.Client.users[data.user_id].discriminator,
          "voice_status": voice_status,
          "channel": if data.channel then data.channel.name else undefined
        }
      }
    }), "VoiceUpdate.png")

module.exports = VoiceChannelUpdateEvent