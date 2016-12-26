Table = require 'cli-table'

class motorbotEventHandler

  constructor: (@app, @client) ->
    @setUpEvents()

  setUpEvents: () ->
    self = @
    @client.on("ready", () ->
      console.log "Motorbot ready"
    )

    @client.on("message", (msg) ->
      if msg.content.match(/^\!v\sjoin/)
        channelName = msg.content.replace(/^\!v\sjoin\s/,"")
        joined = false
        if channelName
          for channel in self.client.guilds[msg.guild_id].channels
            if channel.name == channelName && channel.type == 2
              channel.join().then((VoiceConnection) ->
                self.app.voiceConnections[msg.guild_id] = VoiceConnection
              )
              joined = true
              break
        if !joined
          for channel in self.client.guilds[msg.guild_id].channels
            if channel.type == 2
              channel.join().then((VoiceConnection) ->
                self.app.voiceConnections[msg.guild_id] = VoiceConnection
              )
              break
      else if msg.content == "!v leave"
        self.client.leaveVoiceChannel(msg.guild_id)
      else if msg.content == "!v play"
        if !musicPlayers[msg.guild_id]
          @app.nextSong()
        else
          musicPlayers[msg.guild_id].play()
      else if msg.content == "!v stop"
        musicPlayers[msg.guild_id].stop()
      else if msg.content == "!v pause"
        musicPlayers[msg.guild_id].pause()
      else if msg.content == "!ping"
        msg.channel.sendMessage("pong!")
      else if msg.content == "!dev client status"
        server = msg.guild_id
        content = "Motorbot is connected to your gateway server on **"+self.client.internals.gateway+"** with an average ping of **"+Math.round(self.client.internals.avgPing*100)/100+"ms**. The last ping was **"+self.client.internals.pings[self.client.internals.pings.length-1]+"ms**."
        msg.channel.sendMessage(content)
      else if msg.content.match(/^\!dev voice status/)
        additionalParams = msg.content.replace(/^\!dev voice status\s/gmi,"")
        server = msg.guild_id
        if self.client.voiceHandlers[server]
          bytes = self.client.voiceHandlers[server].bytesTransmitted
          units = "Bytes"
          if bytes > 1024
            bytes = (Math.round((bytes/1024)*100)/100)
            units = "KB"
            if bytes > 1024
              bytes = (Math.round((bytes/1024)*100)/100)
              units = "MB"
              if bytes > 1024
                bytes = (Math.round((bytes/1024)*100)/100)
                units = "GB"
          content = "Motorbot is connected to your voice server on **"+self.client.voiceHandlers[server].endpoint+"** with an average ping of **"+Math.round(self.client.voiceHandlers[server].avgPing*100)/100+"ms**. The last ping was **"+self.client.voiceHandlers[server].pings[self.client.voiceHandlers[server].pings.length-1]+"ms**.\n"
          if additionalParams == "detailed"
            table = new Table({
      #head: ["Parameter","Value"]
              style: {'padding-left':1, 'padding-right':1, head:[], border:[]}
            })
            avgPing = (Math.round(self.client.voiceHandlers[server].avgPing*100)/100)
            connectedTime = (Math.round(((new Date().getTime() - self.client.voiceHandlers[server].connectTime)/1000)*10)/10)
            table.push(["Endpoint",self.client.voiceHandlers[server].endpoint])
            table.push(["Local Port",self.client.voiceHandlers[server].localPort])
            table.push(["Average Ping",avgPing+"ms"])
            table.push(["Last Ping",self.client.voiceHandlers[server].pings[self.client.voiceHandlers[server].pings.length-1]+"ms"])
            table.push(["Heartbeats Sent",self.client.voiceHandlers[server].pings.length])
            table.push(["Bytes Transmitted",bytes+" "+units])
            table.push(["Sequence",self.client.voiceHandlers[server].sequence])
            table.push(["Timestamp",self.client.voiceHandlers[server].timestamp])
            table.push(["Source ID (ssrc)",self.client.voiceHandlers[server].ssrc])
            table.push(["mode","xsalsa20_poly1305"])
            table.push(["User ID",self.client.voiceHandlers[server].user_id])
            table.push(["Session",self.client.voiceHandlers[server].session_id])
            table.push(["Token",self.client.voiceHandlers[server].token])
            table.push(["Connected",connectedTime+"s"])
            content = "```markdown\n"+table.toString()+"\n```"
            if !self.client.voiceHandlers[server].pings[0]
              content += "\n```diff\n- Status: Unknown - Too soon to tell\n```"
            else if avgPing >= 35
              content += "\n```diff\n- Status: Poor - Pings a bit high, switch servers?\n```"
            else if connectedTime >= 172800
              content += "\n```diff\n- Status: Sweating - Been working for at least 48 hours straight\n```"
            else
              content += "\n```diff\n+ Status: Awesome\n```"
          msg.channel.sendMessage(content)
        else
          msg.channel.sendMessage("```diff\n- Not Currently in voice channel\n```")
      else if msg.content == "!react"
        msg.channel.sendMessage("Reacting!")
      else if msg.content == "Reacting!" && msg.author.id == "169554882674556930"
        msg.addReaction("%F0%9F%91%BB")
      else if msg.content == "getMessages"
        console.log "Getting Messages"
        msg.channel.getMessages({limit: 5}).then((messages) ->
          console.log messages[0]
        ).catch((err) ->
          console.log err.statusMessage
        )
      else if msg.content == "getInvites"
        msg.channel.getInvites().then((invites) ->
          console.log invites
        ).catch((err) ->
          console.log err.statusMessage
        )
      else if msg.content == "createInvite"
        msg.channel.createInvite().then((invite) ->
          console.log invite
        ).catch((err) ->
          console.log err.statusMessage
        )
      else if msg.content == "triggerTyping"
        msg.channel.triggerTyping()
      else if msg.content.match(/^setChannelName\s/gmi)
        name = msg.content.replace(/^setChannelName\s/gmi,"")
        msg.channel.setChannelName(name)
      else if msg.content.match(/^setUserLimit\s/gmi)
        user_limit = parseInt(msg.content.replace(/^setUserLimit\s/gmi,""))
        self.client.channels["194904787924418561"].setUserLimit(user_limit)
      )

module.exports = motorbotEventHandler