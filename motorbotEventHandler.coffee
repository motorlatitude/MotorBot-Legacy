Table = require 'cli-table'
keys = require '/var/www/motorbot/keys.json'
apiai = require('apiai')
apiai = apiai(keys.apiai) #AI for !talk method
fs = require 'fs'
req = require 'request'
say = require('say');

class motorbotEventHandler

  constructor: (@app, @client) ->
    @setUpEvents()

  setupSoundboard: (guild_id, filepath, volume = 1) ->
    self = @
    if !self.app.soundboard[guild_id]
      self.app.voiceConnections[guild_id].playFromFile(filepath).then((audioPlayer) ->
        self.app.soundboard[guild_id] = audioPlayer
        self.app.org_volume = 0.5
        self.app.soundboard[guild_id].on('ready', () ->
          if self.app.musicPlayers[guild_id]
            self.app.org_volume = self.app.musicPlayers[guild_id].getVolume()
            self.app.musicPlayers[guild_id].pause()
          else
            self.app.soundboard[guild_id].setVolume(volume)
            self.app.soundboard[guild_id].play()
        )
        self.app.soundboard[guild_id].on('streamDone', () ->
          self.app.debug("StreamDone Received")
          self.app.soundboard[guild_id] = undefined
          if self.app.musicPlayers[guild_id]
            self.app.musicPlayers[guild_id].setVolume(self.app.org_volume)
            self.app.musicPlayers[guild_id].play()
        )
        self.app.musicPlayers[guild_id].on("paused", () ->
          if self.app.soundboard[guild_id]
            self.app.soundboard[guild_id].setVolume(volume)
            self.app.soundboard[guild_id].play()
        )
      )
    else
      self.app.debug("Soundboard already playing")

  setUpEvents: () ->
    self = @
    @client.on("ready", () ->
      self.app.debug("Ready!")
    )

    @client.on("voiceChannelUpdate", (data) ->
      if data.channel
        self.app.websocket.broadcast(JSON.stringify({type: "voiceUpdate", status: "join", channel: data.channel.name}))
      else
        self.app.websocket.broadcast(JSON.stringify({type: "voiceUpdate", status: "leave", channel: undefined}))
    )

    @client.on("message", (msg) ->
        if msg.content.match(/^\!voice\sjoin/)
          channelName = msg.content.replace(/^\!voice\sjoin\s/,"")
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
        else if msg.content.match(/^!dev\stts\s/gmi)
          ttsmessage = msg.content.replace(/^!dev\stts\s/gmi,"")
          ###say.export(ttsmessage, "voice_default", 1, __dirname+"/soundboard/voice.wav", (err) ->
            if err
              self.app.debug("Error Occurred Generating TTS Message")
              console.log err
            self.setupSoundboard(msg.guild_id, __dirname+"/soundboard/voice.wav")
          )###
          self.setupSoundboard(msg.guild_id, __dirname+"/"+ttsmessage+".wav")
        else if msg.content.match(/^!ban doug/gmi)
          msg.channel.sendMessage("If only I could :rolling_eyes: <@"+msg.author.id+">")
        else if msg.content.match(/^!kys/gmi) || msg.content.match(/kys/gmi)
          msg.channel.sendMessage("Calm down before you go and hurt someone <@"+msg.author.id+">")
        else if msg.content.match(/fight\sme(\sbro|)/gmi) || msg.content.match(/come\sat\sme(\sbro|)/gmi)
          msg.channel.sendMessage("(ง’̀-‘́)ง")
        else if msg.content == "!voice leave"
          self.client.leaveVoiceChannel(msg.guild_id)
        else if msg.content.match(/heads\sor\stails(\?|)/gmi)
          if Math.random() >= 0.5
            msg.channel.sendMessage(":one: Heads <@"+msg.author.id+">")
          else
            msg.channel.sendMessage(":zero: Tails <@"+msg.author.id+">")
        else if msg.content.match(/cum\son\sme/)
          msg.channel.sendMessage("8====D- -- - (O)")
        else if msg.content.match(/^(!(initiate\s|)self(\s|)destruct(\ssequence|)|!kill(\s|)me)/gmi)
          output_msg = ":cold_sweat: No pleeeaaassssseee, I have children :cry: https://pbs.twimg.com/media/Cefcn6zW8AA09mQ.jpg"
          msg.channel.sendMessage(output_msg)
        else if msg.content.match(/\!random/)
          msg.channel.sendMessage("Random Number: "+(Math.round((Math.random()*100))))
        else if msg.content == "!sb diddly"
          self.setupSoundboard(msg.guild_id, __dirname+"/soundboard/DootDiddly.mp3", 5)
        else if msg.content == "!sb pog"
          self.setupSoundboard(msg.guild_id, __dirname+"/soundboard/play of the game.mp3", 3)
        else if msg.content == "!sb kled"
          self.setupSoundboard(msg.guild_id, __dirname+"/soundboard/Kled.mp3", 3)
        else if msg.content == "!sb wonder"
          self.setupSoundboard(msg.guild_id, __dirname+"/soundboard/wonder.mp3", 3)
        else if msg.content == "!sb 1"
          self.setupSoundboard(msg.guild_id, __dirname+"/soundboard/1.mp3", 3)
        else if msg.content == "!sb 2"
          self.setupSoundboard(msg.guild_id, __dirname+"/soundboard/2.mp3", 3)
        else if msg.content == "!sb 3"
          self.setupSoundboard(msg.guild_id, __dirname+"/soundboard/3.mp3", 3)
        else if msg.content == "!sb affirmative"
          self.setupSoundboard(msg.guild_id, __dirname+"/soundboard/affirmative.mp3", 3)
        else if msg.content == "!sb gp"
          self.setupSoundboard(msg.guild_id, __dirname+"/soundboard/gp.mp3", 3)
        else if msg.content == "!sb justice"
          self.setupSoundboard(msg.guild_id, __dirname+"/soundboard/justice 3.mp3", 3)
        else if msg.content == "!sb speed boost"
          self.setupSoundboard(msg.guild_id, __dirname+"/soundboard/speed boost.mp3", 3)
        else if msg.content == "!sb stop the payload"
          self.setupSoundboard(msg.guild_id, __dirname+"/soundboard/stop the payload.mp3", 3)
        else if msg.content == "!sb wsr"
          self.setupSoundboard(msg.guild_id, __dirname+"/soundboard/wsr.mp3", 2)
        else if msg.content == "!sb happy birthday adz"
          self.setupSoundboard(msg.guild_id, __dirname+"/soundboard/happybirthdayadz.wav", 3)
        else if msg.content == "!sb stop"
          self.app.soundboard[msg.guild_id].stop()
          self.app.soundboard[msg.guild_id] = undefined
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
              table.push(["Buffer Size",self.client.voiceHandlers[server].buffer_size])
              table.push(["Bytes Transmitted",bytes+" "+units])
              table.push(["Sequence",self.client.voiceHandlers[server].sequence])
              table.push(["Timestamp",self.client.voiceHandlers[server].timestamp])
              table.push(["Source ID (ssrc)",self.client.voiceHandlers[server].ssrc])
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
        else if msg.content.match(/^!lolstat(\s|\.euw|\.na|\.br|\.eune|\.kr|\.lan|\.las|\.oce|\.ru|\.tr|\.jp)/gmi)
          region = "euw"
          if msg.content.replace(/^!lolstat/gmi,"").indexOf(".") > -1
            region = msg.content.replace(/^!lolstat/gmi,"").split(".")[1].split(/\s/gmi)[0]
          summoner = encodeURI(msg.content.replace(/^!lolstat(\s|\.euw|\.na|\.br|\.eune|\.kr|\.lan|\.las|\.oce|\.ru|\.tr|\.jp)/gmi,"").replace(/\s/gmi,"").toLowerCase())
          msg.channel.sendMessageWithFile("",req('https://api.lolstat.net/discord/profile/'+summoner+'/'+region), "profile.png")
        else if msg.content == "!getMessages"
          console.log "Getting Messages"
          msg.channel.getMessages({limit: 5}).then((messages) ->
            console.log messages[0]
          ).catch((err) ->
            console.log err.statusMessage
          )
        else if msg.content == "!getInvites"
          msg.channel.getInvites().then((invites) ->
            console.log invites
          ).catch((err) ->
            console.log err.statusMessage
          )
        else if msg.content == "!createInvite"
          msg.channel.createInvite().then((invite) ->
            console.log invite
          ).catch((err) ->
            console.log err.statusMessage
          )
        else if msg.content == "!triggerTyping"
          msg.channel.triggerTyping()
        else if msg.content.match(/^setChannelName\s/gmi)
          name = msg.content.replace(/^setChannelName\s/gmi,"")
          msg.channel.setChannelName(name)
        else if msg.content.match(/^\!setUserLimit\s/gmi)
          user_limit = parseInt(msg.content.replace(/^setUserLimit\s/gmi,""))
          self.client.channels["194904787924418561"].setUserLimit(user_limit)
        else if msg.content.match(/^\!test_embed/)
          msg.channel.sendMessage("",{
            embed: {
              title: "Status: Awesome",
              #description: "Big ass description"
              color: 6795119,
              ###
              fields:[{
                name:"name of field"
                value:"value of field",
                inline:true
              },{
                name:"name of field"
                value:"value of field"
                inline:false
              }],
              footer: {
                text: "squírrel",
                icon_url: "https://discordapp.com/api/users/95164972807487488/avatars/de1f84de5db24c6681e8447a8106dfd9.jpg"
              }###
            }
          })
        else if msg.content == "Reacting!" && msg.author.id == "169554882674556930"
          msg.addReaction("%F0%9F%91%BB")
        else
          #do nothing, aint a command or anything
    )

module.exports = motorbotEventHandler