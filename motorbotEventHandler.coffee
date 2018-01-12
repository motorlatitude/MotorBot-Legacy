Table = require 'cli-table'
keys = require '/var/www/motorbot/keys.json'
apiai = require('apiai')
apiai = apiai(keys.apiai) #AI for !talk method
fs = require 'fs'
req = require 'request'
moment = require 'moment'
cheerio = require 'cheerio'
say = require 'say'

class motorbotEventHandler

  constructor: (@app, @client) ->
    @setUpEvents()
    @already_announced = false

  setupSoundboard: (guild_id, filepath, volume = 1) ->
    self = @
    if !self.app.soundboard[guild_id]
      self.app.voiceConnections[guild_id].playFromFile(filepath).then((audioPlayer) ->
        self.app.soundboard[guild_id] = audioPlayer
        self.app.org_volume = 0.5 #set default
        self.app.soundboard[guild_id].on('streamDone', () ->
          self.app.debug("StreamDone Received")
          self.app.soundboard[guild_id] = undefined
          if self.app.musicPlayers[guild_id]
            self.app.musicPlayers[guild_id].setVolume(self.app.org_volume) #set back to original volume of music
            self.app.musicPlayers[guild_id].play()
        )
        self.app.soundboard[guild_id].on('ready', () ->
          if self.app.musicPlayers[guild_id]
            self.app.org_volume = self.app.musicPlayers[guild_id].getVolume()
            self.app.musicPlayers[guild_id].pause()
          else
            self.app.soundboard[guild_id].setVolume(volume)
            self.app.soundboard[guild_id].play()
        )
        self.app.musicPlayers[guild_id].on("paused", () ->
          if self.app.soundboard[guild_id]
            self.app.soundboard[guild_id].setVolume(volume)
            self.app.soundboard[guild_id].play()
        )
      )
    else
      self.app.debug("Soundboard already playing")

  twitchSubscribeToStream: (user_id) ->
    # Subscribe to Twitch Webhook Services
    req.post({
        url: "https://api.twitch.tv/helix/webhooks/hub?hub.mode=subscribe&hub.topic=https://api.twitch.tv/helix/streams?user_id="+user_id+"&hub.callback=https://mb.lolstat.net/twitch/callback&hub.lease_seconds=864000&hub.secret=hexweaver"
        headers: {
          "Client-ID": "1otsv80onfatqfom7ny85js3vakssl"
        },
        json: true
      }, (error, httpResponse, body) ->
      console.log "Twitch Webhook Subscription Response Code: "+httpResponse.statusCode
      if error
        console.log "subscription error to webhook"
        console.log error

      console.log body
    )

  setUpEvents: () ->
    self = @
    self.twitchSubscribeToStream(22032158) #motorlatitude
    self.twitchSubscribeToStream(26752266) #mutme
    self.twitchSubscribeToStream(24991333) #imaqtpie
    self.twitchSubscribeToStream(22510310) #GDQ

    @client.on("ready", () ->
      self.app.debug("Ready!")
    )

    @client.on("voiceChannelUpdate", (data) ->
      if data.user_id == '169554882674556930'
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
        else if msg.content.match(/^\!voice\s(.*?)\sjoin/)
          channelName = msg.content.replace(/^\!voice\s(.*?)\sjoin\s/,"")
          selected_guild_id = msg.content.match(/^\!voice\s(.*?)\sjoin/)[1]
          console.log msg.author
          joined = false
          if self.client.guilds[selected_guild_id]
            if channelName
              for channel in self.client.guilds[selected_guild_id].channels
                if channel.name == channelName && channel.type == 2
                  channel.join().then((VoiceConnection) ->
                    self.app.voiceConnections[selected_guild_id] = VoiceConnection
                  )
                  joined = true
                  break
            if !joined
              for channel in self.client.guilds[selected_guild_id].channels
                if channel.type == 2
                  channel.join().then((VoiceConnection) ->
                    self.app.voiceConnections[selected_guild_id] = VoiceConnection
                  )
                  break
          else
            msg.channel.sendMessage("```diff\n- Unknown Server\n```")
        else if msg.content.match(/^\!voice\s(.*?)\sleave/)
          selected_guild_id = msg.content.match(/^\!voice\s(.*?)\sleave/)[1]
          console.log msg.author
          if self.client.guilds[selected_guild_id]
            self.client.leaveVoiceChannel(selected_guild_id)
          else
            msg.channel.sendMessage("```diff\n- Unknown Server\n```")
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
        else if msg.content == "!sb drop"
          self.setupSoundboard(msg.guild_id, __dirname+"/soundboard/drop_beat.wav", 3)
        else if msg.content == "!sb tears"
          self.setupSoundboard(msg.guild_id, __dirname+"/soundboard/bings_tears.wav", 3)
        else if msg.content == "!sb balanced"
          self.setupSoundboard(msg.guild_id, __dirname+"/soundboard/balancing_teams.wav", 3)
        else if msg.content == "!sb ez mode"
          self.setupSoundboard(msg.guild_id, __dirname+"/soundboard/D.Va_-_Easy_mode.ogg", 3)
        else if msg.content == "!sb enemy"
          self.setupSoundboard(msg.guild_id, __dirname+"/soundboard/Enemy Slain.mp3", 2)
        else if msg.content == "!sb victory"
          self.setupSoundboard(msg.guild_id, __dirname+"/soundboard/Victory.mp3", 2)
        else if msg.content == "!sb defeat"
          self.setupSoundboard(msg.guild_id, __dirname+"/soundboard/Defeat.mp3", 2)
        else if msg.content == "!sb pentakill"
          self.setupSoundboard(msg.guild_id, __dirname+"/soundboard/Pentakill1.mp3", 2)
        else if msg.content == "!sb happy birthday adz"
          self.setupSoundboard(msg.guild_id, __dirname+"/soundboard/happybirthdayadz.wav", 3)
        else if msg.content == "!sb stop"
          self.app.soundboard[msg.guild_id].stop()
          self.app.soundboard[msg.guild_id] = undefined
        else if msg.content == "!sb help"
          msg.channel.sendMessage("",{
            embed: {
              title: "Soundboard Commands",
              description: "**!sb diddly** - Doot Diddly\n
              **!sb pog** - Play Of The Game\n
              **!sb kled** - I Find Courage Unpredictable...\n
              **!sb wonder** - And I sometimes wonder...\n
              **!sb 1** - Overwatch Announcer: One\n
              **!sb 2** - Overwatch Announcer: Two\n
              **!sb 3** - Overwatch Announcer: Three\n
              **!sb affirmative** - Affirmative\n
              **!sb gp** - 100% German Power\n
              **!sb justice** - Justice Rains From Above\n
              **!sb speed boost** - Speed Boost\n
              **!sb stop the payload** - Stop The Payload\n
              **!sb wsr** - Welcome To Summoner's Rift\n
              **!sb happy birthday adz** - Happy Birthday To Adz\n
              **!sb drop** - Drop The Beat\n
              **!sb tears** - Brings Tears\n
              **!sb balanced** - Balancing Teams\n
              **!sb ez mode** - Is this easy mode?\n
              **!sb enemy** - Enemy Slain\n
              **!sb victory** - Victory\n
              **!sb defeat** - Defeat\n
              **!sb pentakill** - PENTAKILL\n\n
              **!sb stop** - Resets the soundboard, useful if the soundboard commands aren't working"
              color: 39125
            }
          })
        else if msg.content == "!help"
          msg.channel.sendMessage("",{
            embed: {
              title: "Motorbot Commands",
              description: "**!voice {guild_id} join {channel_name}** *- join a voice channel, {channel_name} and {guild_id} are optional*\n
              **!voice {guild_id} leave** *- leave voice channel, {guild_id} are optional*\n
              **!ban doug** *- bans doug*\n
              **!kys** *- KYS*\n
              **heads or tails** *- 50/50 chance*\n
              **fight me** *- you looking for a fight?*\n
              **cum on me** *- ...*\n
              **!random** *- generates a random number between 0 and 100*\n
              **!sb** *- soundboard (!sb help to get help with the soundboard)*\n
              **!ping** *- pong (dev test)*\n
              **!dev** *- bunch of dev status commands*\n
              **!react** *- react test*\n
              **!lolstat{.region} {summoner_name}** *- lolstat profile, {.region} is optional*\n
              **!ow {battlenet id}** *- gets some Overwatch Stats*\n
              **!triggerTyping** *- triggers typing indicator*\n
              **!reddit {subreddit}** *- gets the top 5 posts for /r/all, unless subreddit is specified e.g. `!reddit linuxmasterrace`*
              "
              color: 46066
            }
          })
        else if msg.content == "!ping"
          msg.channel.sendMessage("pong!")
        else if msg.content.match(/^\!dev client status/)
          server = msg.guild_id
          content = "Motorbot is connected to your gateway server on **"+self.client.internals.gateway+"** with an average ping of **"+Math.round(self.client.internals.avgPing*100)/100+"ms**. The last ping was **"+self.client.internals.pings[self.client.internals.pings.length-1]+"ms**."
          additionalParams = msg.content.replace(/^\!dev client status\s/gmi,"")
          if additionalParams == "detailed"
            table = new Table({
              style: {'padding-left':1, 'padding-right':1, head:[], border:[]}
            })
            avgPing = Math.round(self.client.internals.avgPing*100)/100
            table.push(["Endpoint",self.client.internals.gateway])
            table.push(["Average Ping",avgPing+"ms"])
            table.push(["Last Ping",self.client.internals.pings[self.client.internals.pings.length-1]+"ms"])
            table.push(["Heartbeats Sent",self.client.internals.pings.length])
            table.push(["Sequence",self.client.internals.sequence])
            table.push(["Connected Guilds",Object.keys(self.client.guilds).length])
            table.push(["Channels",Object.keys(self.client.channels).length])
            table.push(["Active Voice Handlers",Object.keys(self.client.voiceHandlers).length])
            table.push(["Connection Retry Count",self.client.internals.connection_retry_count])
            table.push(["Resuming", self.client.internals.resuming])
            content = "```markdown\n"+table.toString()+"\n```"
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
        else if msg.content.match(/^!ow\s/gmi)
          battle_id = msg.content.replace(/^!ow\s/gmi, "").replace("#","-")
          req({
            url: "https://playoverwatch.com/en-gb/career/pc/eu/"+battle_id
          }, (error, httpResponse, body) ->
            console.log "Overwatch Request Complete"
            if error then console.log error
            $ = cheerio.load(body)
            wins = $(".masthead .masthead-detail span").text()
            if wins
              quickplayStats = ""
              $("#quickplay > section.content-box.u-max-width-container.highlights-section > div > ul > li").each((i, elem) ->
                quickplayStats += $(elem).find(".card > .card-content > .card-copy").text().replace(" - Average","")+": "+$(this).find(".card > .card-content > .card-heading").text()+"\n"
              )
              competitiveStats = ""
              $("#competitive > section.content-box.u-max-width-container.highlights-section > div > ul > li").each((i, elem) ->
                competitiveStats += $(elem).find(".card > .card-content > .card-copy").text().replace(" - Average","")+": "+$(this).find(".card > .card-content > .card-heading").text()+"\n"
              )
              msg.channel.reply("",{
                embed:{
                  title: $("#overview-section > div > div.u-max-width-container.row.content-box.gutter-18 > div > div > div.masthead-player > h1").text(),
                  url: "https://playoverwatch.com/en-gb/career/pc/eu/"+battle_id,
                  description: wins,
                  color: 16751872,
                  type: "rich",
                  fields:[{
                    name: "Quick Play"
                    value: quickplayStats,
                    inline: true
                  },{
                    name: "Competitive"
                    value: competitiveStats,
                    inline: true
                  }],
                  thumbnail: {
                    url: $("#overview-section > div > div.u-max-width-container.row.content-box.gutter-18 > div > div > div.masthead-player > img").attr("src")
                  }
                }
              })
            else
              msg.channel.reply("Couldn't find account :(")
          )
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
        else if msg.content.match(/^\!reddit/)
            subreddit = "/r/all"
            cmds = msg.content.replace(/^\!reddit\s/gmi,"")
            if cmds && cmds != "" && cmds != "!reddit" then subreddit = "/r/"+cmds
            req.get({url: "https://www.reddit.com"+subreddit+"/hot.json", json: true}, (err, httpResponse, body) ->
              if err
                utils.debug("Error occurred getting hot from /r/all", "error")
                msg.channel.sendMessage("",{embed: {
                    title: "Error Occurred Retrieving Hot Posts from /r/all",
                    color: 6795119
                  }
                })
              else
                count = 5
                i = 0
                if body.data
                  if body.data.children
                    for post in body.data.children
                      if i >= count then break
                      i++
                      if post.data.thumbnail && post.data.thumbnail != "self" && post.data.thumbnail != "default" && post.data.thumbnail != "spoiler" && post.data.thumbnail.match(/^https\:(.*?)/)
                        msg.channel.sendMessage("",{embed:{
                            title: "[/"+post.data.subreddit_name_prefixed+"] "+post.data.title,
                            url: "https://www.reddit.com"+post.data.permalink,
                            color: 16728832,
                            type: "rich",
                            fields:[{
                              name: "Score"
                              value: post.data.score,
                              inline: true
                            },{
                              name: "Comments"
                              value: post.data.num_comments,
                              inline: true
                            },{
                              name: "Published"
                              value: moment.unix(post.data.created_utc).format("DD/MM/YYYY [at] HH:mm"),
                              inline: true
                            },{
                              name: "Author"
                              value: "/u/"+post.data.author,
                              inline: true
                            }],
                            thumbnail: {
                              url: post.data.thumbnail
                            }
                          }
                        })
                      else
                        msg.channel.sendMessage("",{embed:{
                            title: "[/"+post.data.subreddit_name_prefixed+"] "+post.data.title,
                            url: "https://www.reddit.com"+post.data.permalink,
                            color: 1601757,
                            type: "rich",
                            fields:[{
                              name: "Score"
                              value: post.data.score,
                              inline: true
                            },{
                              name: "Comments"
                              value: post.data.num_comments,
                              inline: true
                            },{
                              name: "Published"
                              value: moment.unix(post.data.created_utc).format("DD/MM/YYYY [at] HH:mm"),
                              inline: true
                            },{
                              name: "Author"
                              value: "/u/"+post.data.author,
                              inline: true
                            }]
                          }
                        })
            )
            msg.delete()
        else
          #do nothing, aint a command or anything
    )

module.exports = motorbotEventHandler