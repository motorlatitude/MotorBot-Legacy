Table = require 'cli-table'
keys = require '/var/www/motorbot/keys.json'
apiai = require('apiai')
apiai = apiai(keys.apiai) #AI for !talk method
fs = require 'fs'
req = require 'request'
moment = require 'moment'
cheerio = require 'cheerio'
say = require 'say'
turndown = require 'turndown'

class motorbotEventHandler

  constructor: (@app, @client) ->
    @setUpEvents()
    @already_announced = false
    @challenged = {}
    @challenger = {}

  setupSoundboard: (guild_id, filepath, volume = 1) ->
    self = @
    if !self.app.soundboard[guild_id]
      self.app.client.voiceConnections[guild_id].playFromFile(filepath).then((audioPlayer) ->
        self.app.soundboard[guild_id] = audioPlayer
        self.app.org_volume = 0.5 #set default
        self.app.soundboard[guild_id].on('streamDone', () ->
          self.app.debug("StreamDone Received")
          delete self.app.soundboard[guild_id]
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

  toTitleCase: (str) ->
    return str.replace(/\w\S*/g, (txt) ->
      return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase()
    );

  patchListener: (game) ->
    self = @
    if game == "ow"
      patches = {}
      p = []
      req({
          url: "https://playoverwatch.com/en-us/game/patch-notes/pc/"
        }, (error, httpResponse, body) ->
        console.log "Overwatch Request Complete"
        if error then console.log error
        $ = cheerio.load(body)
        $(".patch-notes-body").each((i, element) ->
          p[i] = $(this).attr("id")
          console.log p[i]
          desc = $(this).html().replace(/<\/h2>/,'sdfgpoih345e87th').split('sdfgpoih345e87th')[1]
          patches[$(this).attr("id")] = {
            patch_id: $(this).attr("id"),
            title: $(this).find("h1").text(),
            sub_title: $(this).find("h2").eq(0).text(),
            desc: desc
          }
        )
        #find all logged patches
        patchCollection = self.app.database.collection("patches")
        patchCollection.find({patch_id: {"$in": p}}).toArray((err, results) ->
          if err then return console.log err
          if results[0]
            console.log "found patches in db"
            for result in results
              for patch_id, patch of patches
                if result.patch_id == patch_id
                  delete patches[patch_id] #remove patch from patches array
          #process any left patches
          console.log "processing any left patches"
          td = new turndown()
          database_patches = []
          for key, new_patch of patches
            d = new Date()
            database_patches.push(new_patch)
            embed_element = {
              title: self.toTitleCase(new_patch.title),
              url: "https://playoverwatch.com/en-us/game/patch-notes/pc/#" + new_patch.patch_id,
              description: new_patch.sub_title + "\n------\n" + td.turndown(new_patch.desc).substring(0, 1000) + "\n\n[Read More](https://playoverwatch.com/en-us/game/patch-notes/pc/#" + new_patch.patch_id+")",
              color: 16751872,
              timestamp: d.toISOString(),
              type: "rich",
              "footer": {
                "icon_url": "https://mb.lolstat.net/overwatch_sm.png",
                "text": "Patch Notification"
              },
              thumbnail: {
                url: "https://mb.lolstat.net/overwatch_sm.png"
              }
            }
            console.log embed_element
            self.app.client.channels["438307738250903553"].sendMessage("", {
              embed: embed_element
            })
          if database_patches.length > 0
            patchCollection.insertMany(database_patches)
        )
      )


  twitchSubscribeToStream: (user_id) ->
    # Subscribe to Twitch Webhook Services
    self = @
    req.post({
        url: "https://api.twitch.tv/helix/webhooks/hub?hub.mode=subscribe&hub.topic=https://api.twitch.tv/helix/streams?user_id="+user_id+"&hub.callback=https://mb.lolstat.net/twitch/callback&hub.lease_seconds=864000&hub.secret=hexweaver"
        headers: {
          "Client-ID": keys.twitch
        },
        json: true
      }, (error, httpResponse, body) ->
        self.app.debug("Twitch Webhook Subscription Response Code: "+httpResponse.statusCode, "debug")
        if error
          self.app.debug("subscription error to webhook", "error")
          console.log error
    )

  changeNickname: (guild_id, user_id, user_name, karma) ->
    # doesn't work for same roles and roles above bots current role
    ###req({
        url: "https://discordapp.com/api/guilds/"+guild_id+"/members/"+user_id,
        method: "PATCH"
        headers: {
          "Authorization": "Bot "+keys.token
        },
        json: true
        body: {
          nick: user_name+" ("+karma+")"
        }
    }, (err, httpResponse, body) ->
      if err then console.log err
      console.log "request complete"
      console.log body
    )###

  rockPaperScissors: (msg, author, choice) ->
    self = @
    compareRPS = (challenged, challengedID, challenger, challengerID, cb) ->
      outcome = {
        winner: undefined,
        challenged: {
          id: challengedID
          win: true
        },
        challenger: {
          id: challengerID
          win: true
        }
      }
      if challenged.choice == "rock"
        if challenger.choice == "paper"
          outcome.challenger.win = true
          outcome.challenged.win = false
          outcome.winner = challengerID
        if challenger.choice == "rock"
          outcome.challenger.win = true
          outcome.challenged.win = true
          outcome.winner = "tie"
        if challenger.choice == "scissors"
          outcome.challenger.win = false
          outcome.challenged.win = true
          outcome.winner = challengedID
      else if challenged.choice == "paper"
        if challenger.choice == "paper"
          outcome.challenger.win = true
          outcome.challenged.win = true
          outcome.winner = "tie"
        if challenger.choice == "rock"
          outcome.challenger.win = false
          outcome.challenged.win = true
          outcome.winner = challengedID
        if challenger.choice == "scissors"
          outcome.challenger.win = true
          outcome.challenged.win = false
          outcome.winner = challengerID
      else if challenged.choice == "scissors"
        if challenger.choice == "paper"
          outcome.challenger.win = false
          outcome.challenged.win = true
          outcome.winner = challengedID
        if challenger.choice == "rock"
          outcome.challenger.win = true
          outcome.challenged.win = false
          outcome.winner = challengerID
        if challenger.choice == "scissors"
          outcome.challenger.win = true
          outcome.challenged.win = true
          outcome.winner = "tie"
      cb(outcome)
    if self.challenged[author]
      self.challenged[author].choice = choice
      challenger = self.challenger[self.challenged[author].challenger]
      if self.challenger[self.challenged[author].challenger].choice
        #both users have made their choice, compare
        compareRPS(self.challenged[author], author, self.challenger[self.challenged[author].challenger], self.challenged[author].challenger, (outcome) ->
          if outcome.winner == "tie"
            challenger.channel.sendMessage("The challenge between <@"+author+"> and <@"+self.challenged[author].challenger+"> resulted in a draw, fight again?")
            delete self.challenger[self.challenged[author].challenger]
            delete self.challenged[author]
          else
            if self.challenged[outcome.winner]
              challenger.channel.sendMessage("Aaaaaannndd the winner is... <@"+outcome.winner+"> :trophy:, congratulations. Better luck next time <@"+self.challenged[outcome.winner].challenger+">")
              delete self.challenger[self.challenged[outcome.winner].challenger]
              delete self.challenged[outcome.winner]
            else if self.challenger[outcome.winner]
              challenger.channel.sendMessage("Aaaaaannndd the winner is... <@"+outcome.winner+"> :trophy:, congratulations. Better luck next time <@"+self.challenger[outcome.winner].challenged+">")
              delete self.challenged[self.challenger[outcome.winner].challenged]
              delete self.challenger[outcome.winner]
        )
    if self.challenger[author]
      self.challenger[author].choice = choice
      challenger = self.challenger[author]
      if self.challenged[self.challenger[author].challenged].choice
        #both users have made their choice, compare
        compareRPS(self.challenged[self.challenger[author].challenged], self.challenger[author].challenged, self.challenger[author], author, (outcome) ->
          if outcome.winner == "tie"
            challenger.channel.sendMessage("The challenge between <@"+author+"> and <@"+self.challenger[author].challenged+"> resulted in a draw, fight again?")
            delete self.challenged[self.challenger[author].challenged]
            delete self.challenger[author]
          else
            if self.challenged[outcome.winner]
              challenger.channel.sendMessage("Aaaaaannndd the winner is... <@"+outcome.winner+"> :trophy:, congratulations. Better luck next time <@"+self.challenged[outcome.winner].challenger+">")
              delete self.challenger[self.challenged[outcome.winner].challenger]
              delete self.challenged[outcome.winner]
            else if self.challenger[outcome.winner]
              challenger.channel.sendMessage("Aaaaaannndd the winner is... <@"+outcome.winner+"> :trophy:, congratulations. Better luck next time <@"+self.challenger[outcome.winner].challenged+">")
              delete self.challenged[self.challenger[outcome.winner].challenged]
              delete self.challenger[outcome.winner]
        )

  setUpEvents: () ->
    self = @
    self.twitchSubscribeToStream(22032158) #motorlatitude
    self.twitchSubscribeToStream(26752266) #mutme
    self.twitchSubscribeToStream(24991333) #imaqtpie
    self.twitchSubscribeToStream(22510310) #GDQ
    #League LCS
    self.twitchSubscribeToStream(36029255) #RiotGames
    self.twitchSubscribeToStream(36794584) #RiotGames2


    @client.on("ready", () ->
      self.app.debug("Ready!")
    )

    y = 0
    @client.on("guildCreate", (server) ->
      if self.client.channels["432351112616738837"]
        d = new Date()
        time = "`["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"]` "
        if server.id == "130734377066954752"
          self.client.channels["432351112616738837"].sendMessage(":x: <@&443191635657097217>","embed": {
            "title": "MOTORBOT RESTARTED"
            "description": "Motorbot had to restart either through manual input or due to a fatal error occurring, please consult error logs in console if the latter.",
            "color": 16724787
          })
        #self.client.channels["432351112616738837"].sendMessage(time + " Joined Guild: "+server.name+" ("+server.presences.length+" online / "+(parseInt(server.member_count)-server.presences.length)+" offline)")
        if y == 0
          #Listen for patches
          #setInterval( () ->
            #self.patchListener("ow")
          #, 3600000)
          y = 1
    )

    @client.on("voiceUpdate_Speaking", (data) ->
      self.app.websocket.broadcast(JSON.stringify({type: "VOICE_UPDATE_SPEAKING", d:data}))
    )

    voiceStates = {}

    @client.on("voiceChannelUpdate", (data) ->
      if data.user_id == '169554882674556930'
        if data.channel
            self.app.websocket.broadcast(JSON.stringify({type: "VOICE_UPDATE", d:{status:"JOIN", channel: data.channel.name, channel_id: data.channel.id, channel_obj: data}}, (key, value) ->
              if key == "client"
                return undefined
              else
                return value
            ))
        else
          self.app.websocket.broadcast(JSON.stringify({type: "VOICE_UPDATE", d:{status:"LEAVE", channel: undefined, channel_id: undefined, channel_obj: data}}, (key, value) ->
            if key == "client"
              return undefined
            else
              return value
          ))
      d = new Date()
      time = "`["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"]` "
      if data.channel
        if voiceStates[data.user_id]
          if voiceStates[data.user_id].channel
            #previously in channel hence channel voice state change
            #voice state trigger
            if data.deaf && !voiceStates[data.user_id].deaf
              #deafened from server
              self.client.channels["432351112616738837"].sendMessage(time+"<@"+data.user_id+"> was server deafened in the `"+data.channel.name+"` voice channel")
            if data.mute && !voiceStates[data.user_id].mute
              #muted from server
              self.client.channels["432351112616738837"].sendMessage(time+"<@"+data.user_id+"> was server muted in the `"+data.channel.name+"` voice channel")
            if data.self_deaf && !voiceStates[data.user_id].self_deaf
              #user has deafened himself
              self.client.channels["432351112616738837"].sendMessage(time+"<@"+data.user_id+"> has deafened them self in the `"+data.channel.name+"` voice channel")
            if data.self_mute && !voiceStates[data.user_id].self_mute
              #user has muted himself
              self.client.channels["432351112616738837"].sendMessage(time+"<@"+data.user_id+"> has muted them self in the `"+data.channel.name+"` voice channel")
            #voice state trigger reverse
            if !data.deaf && voiceStates[data.user_id].deaf
              #undeafened from server
              self.client.channels["432351112616738837"].sendMessage(time+"<@"+data.user_id+"> is no longer server deafened in the `"+data.channel.name+"` voice channel")
            if !data.mute && voiceStates[data.user_id].mute
              #unmuted from server
              self.client.channels["432351112616738837"].sendMessage(time+"<@"+data.user_id+"> is no longer server muted in the `"+data.channel.name+"` voice channel")
            if !data.self_deaf && voiceStates[data.user_id].self_deaf
              #user has undeafened himself
              self.client.channels["432351112616738837"].sendMessage(time+"<@"+data.user_id+"> is no longer deafened in the `"+data.channel.name+"` voice channel")
            if !data.self_mute && voiceStates[data.user_id].self_mute
              #user has unmuted himself
              self.client.channels["432351112616738837"].sendMessage(time+"<@"+data.user_id+"> is no longer muted in the `"+data.channel.name+"` voice channel")
          else
            #newly joined
            self.client.channels["432351112616738837"].sendMessage(time+"<@"+data.user_id+"> has joined the `"+data.channel.name+"` voice channel")
        else
          self.client.channels["432351112616738837"].sendMessage(time+"<@"+data.user_id+"> has joined the `"+data.channel.name+"` voice channel")
      else
        self.client.channels["432351112616738837"].sendMessage(time+"<@"+data.user_id+"> has left a voice channel")

      voiceStates[data.user_id] = data
    )

    userStatus = {}

    @client.on("status", (user_id,status,game,extra_info) ->
      if extra_info.guild_id == "130734377066954752" #only listening for presence updates in the KTJ guild for now to avoid duplicates across multiple channels
        if game
          self.app.debug(user_id+"'s status ("+status+") has changed; "+game.name+"("+game.type+")","notification")
        else
          self.app.debug(user_id+"'s status ("+status+") has changed", "notification")
        d = new Date()
        time = "`["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"]` "
        gameText = ""
        statusText = ""
        additionalString = ""
        if game
          extra_info["last_game_update"] = new Date().getTime()
          if userStatus[user_id]
            if userStatus[user_id].game
              if userStatus[user_id].game.name == game.name
                extra_info["last_game_update"] = userStatus[user_id].last_game_update
          if game.details
            additionalString += "\n"+time+" *"+game.details+"*"
          if game.state
            additionalString += "\n"+time+" "+game.state

        if userStatus[user_id]
          if userStatus[user_id].status == status
            #no status change, only game update
            if !game && userStatus[user_id].game
              if userStatus[user_id].game.type == 0
                statusText = " has stopped playing **"+userStatus[user_id].game.name+"** after "+(moment.unix(userStatus[user_id].last_game_update/1000).fromNow()).replace(" ago","")
              else if userStatus[user_id].game.type == 1
                statusText = " has stopped streaming **"+userStatus[user_id].game.name+"** after "+(moment.unix(userStatus[user_id].last_game_update/1000).fromNow()).replace(" ago","")
              else if userStatus[user_id].game.type == 2
                statusText = " has stopped listening to **"+userStatus[user_id].game.name+"** after "+(moment.unix(userStatus[user_id].last_game_update/1000).fromNow()).replace(" ago","")
            extra_info["last_update"] = userStatus[user_id].last_update
          else
            #status change
            statusText = " was `"+userStatus[user_id].status+"` for "+(moment.unix(userStatus[user_id].last_update/1000).fromNow()).replace(" ago","")+" and is now `"+status+"`"
            extra_info["last_update"] = new Date().getTime()
        else
          #we don't know previous status so assume status change
          statusText = "'s status has changed to `"+status+"`"
          extra_info["last_update"] = new Date().getTime()

        if game && game.type == 0
          gameText = " is playing **"+game.name+"**"
        else if game && game.type == 1
          gameText = " is streaming **"+game.name+"**"
        else if game && game.type == 2
          gameText = " is listening to **"+game.name+"**"
        else
          gameText = "" #status change

        if game
          if userStatus[user_id]
            if userStatus[user_id].game
              if userStatus[user_id].game.name == game.name && game.type == 0
                gameText = " game presence update :video_game: "
              else if userStatus[user_id].game.name == game.name && game.type == 2
                gameText = " is switching song"

        someText = if(gameText != "" && statusText != "") then " and"+gameText else gameText
        if game && game.type == 2
          additionalString = ""
          if game.details
            additionalString += "\n"+time+" **"+game.details+"**"
          if game.state
            additionalString += "\n"+time+" by "+game.state
          if game.assets.large_text
            additionalString += "\n"+time+" on "+game.assets.large_text
          console.log game
          desc = time+"<@"+user_id+">"+statusText+someText+additionalString
          thumbnail_url = ""
          if game.assets
            if game.assets.large_image
              thumbnail_id = game.assets.large_image.replace("spotify:","")
              thumbnail_url = "https://i.scdn.co/image/"+thumbnail_id
          console.log thumbnail_url
          self.client.channels["432351112616738837"].sendMessage("","embed": {
            "description": desc,
            "color": 2021216,
            "thumbnail": {
              "url": thumbnail_url
            }
          })
        else
          if statusText == "" && someText == "" && additionalString == ""
            self.client.channels["432351112616738837"].sendMessage(time+"<@"+user_id+"> is `invisible` and a status refresh event occurred")
          else
            self.client.channels["432351112616738837"].sendMessage(time+"<@"+user_id+">"+statusText+someText+additionalString)

        userStatus[user_id] = extra_info
    )

    @client.on("reaction", (type, data) ->
      if data.user_id != "169554882674556930"
        d = new Date()
        time = "`["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"]` "
        if data.emoji.name == "downvote" || data.emoji.name == "upvote"
          if type == "add"
            self.client.channels["432351112616738837"].sendMessage(time+"<@"+data.user_id+"> has added the `"+data.emoji.name+"` reaction to message `"+data.message_id+"` in channel <#"+data.channel_id+">")
            #find message for user
            self.client.channels[data.channel_id].getMessage(data.message_id).then((message) ->
              author_id = message.author.id
              karmaCollection = self.app.database.collection("karma_points")
              karmaCollection.find({"author": author_id}).toArray((err, results) ->
                if err then return console.log err
                if results[0]
                  author_karma = results[0].karma
                else
                  author_karma = 0
                if data.emoji.name == "upvote"
                  author_karma += 1
                else if data.emoji.name == "downvote"
                  author_karma -= 1
                karma_obj = {
                  author: author_id,
                  karma: author_karma
                }
                self.client.channels["432351112616738837"].sendMessage(time+"<@"+author_id+"> now has "+author_karma+" karma")
                karmaCollection.update({author: author_id}, karma_obj, {upsert: true})
                self.changeNickname(message.guild_id , author_id, message.author.username, author_karma)
              )
            ).catch((err) ->
              console.log "Couldn't retrieve message"
              console.log err
            )
          else if type == "remove"
            self.client.channels["432351112616738837"].sendMessage(time+"<@"+data.user_id+"> has removed the `"+data.emoji.name+"` reaction on message `"+data.message_id+"` in channel <#"+data.channel_id+">")
            #find message for user
            self.client.channels[data.channel_id].getMessage(data.message_id).then((message) ->
              author_id = message.author.id
              karmaCollection = self.app.database.collection("karma_points")
              karmaCollection.find({"author": author_id}).toArray((err, results) ->
                if err then return console.log err
                if results[0]
                  author_karma = results[0].karma
                else
                  author_karma = 0
                if data.emoji.name == "upvote"
                  author_karma -= 1
                else if data.emoji.name == "downvote"
                  author_karma += 1
                karma_obj = {
                  author: author_id,
                  karma: author_karma
                }
                self.client.channels["432351112616738837"].sendMessage(time+"<@"+author_id+"> now has "+author_karma+" karma")
                karmaCollection.update({author: author_id}, karma_obj, {upsert: true})
                self.changeNickname(message.guild_id , author_id, message.author.username, author_karma)
              )
            ).catch((err) ->
              console.log "Couldn't retrieve message"
              console.log err
            )
    )

    @client.on("message", (msg) ->
        #store all messages
        messageCollection = self.app.database.collection("messages")
        db_msg_obj = {
          id: msg.id,
          channel_id: msg.channel_id,
          guild_id: msg.guild_id,
          author: msg.author,
          content: msg.content,
          timestamp: msg.timestamp,
          edited_timestamp: msg.edited_timestamp,
          tts: msg.tts,
          mention_everyone: msg.mention_everyone,
          mentions: msg.mentions,
          mention_roles: msg.mention_roles,
          attachments: msg.attachments,
          embeds: msg.embeds,
          reactions: msg.reactions,
          nonce: msg.nonce,
          pinned: msg.pinned,
          webhook_id: msg.webhook_id
        }
        messageCollection.update({id: msg.id}, db_msg_obj, {upsert: true})
        if msg.content.match(/^\!voice\sjoin/)
          channelName = msg.content.replace(/^\!voice\sjoin\s/,"")
          joined = false
          if channelName
            for channel in self.client.guilds[msg.guild_id].channels
              if channel.name == channelName && channel.type == 2
                channel.join().then((VoiceConnection) ->
                  self.app.client.voiceConnections[msg.guild_id] = VoiceConnection
                )
                joined = true
                break
          if !joined
            for channel in self.client.guilds[msg.guild_id].channels
              if channel.type == 2
                channel.join().then((VoiceConnection) ->
                  self.app.client.voiceConnections[msg.guild_id] = VoiceConnection
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
                    self.app.client.voiceConnections[selected_guild_id] = VoiceConnection
                  )
                  joined = true
                  break
            if !joined
              for channel in self.client.guilds[selected_guild_id].channels
                if channel.type == 2
                  channel.join().then((VoiceConnection) ->
                    self.app.client.voiceConnections[selected_guild_id] = VoiceConnection
                  )
                  break
          else
            msg.channel.sendMessage("```diff\n- Unknown Server\n```")
        else if msg.content.match(/^\!voice\s(.*?)\sleave/)
          selected_guild_id = msg.content.match(/^\!voice\s(.*?)\sleave/)[1]
          if self.client.guilds[selected_guild_id]
            self.client.leaveVoiceChannel(selected_guild_id)
          else
            msg.channel.sendMessage("```diff\n- Unknown Server\n```")
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
        else if msg.content == "!sb airport"
          self.setupSoundboard(msg.guild_id, __dirname+"/soundboard/En-BAW-LHR-boarding.mp3", 2)
        else if msg.content == "!sb airport de"
          self.setupSoundboard(msg.guild_id, __dirname+"/soundboard/Ge-DLH-FRA-boarding.mp3", 2)
        else if msg.content == "!sb stop"
          if self.app.soundboard[msg.guild_id]
            self.app.soundboard[msg.guild_id].stop()
            delete self.app.soundboard[msg.guild_id]
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
              **!sb pentakill** - PENTAKILL\n
              **!sb airport** - Airport Announcement\n
              **!sb airport de** - German Airport Announcement\n\n
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
        else if msg.content.match(/^\!setStatus\s/gmi)
          newStatus = msg.content.replace(/^\!setStatus\s/gmi,"")
          self.client.setStatus(newStatus, 0, "online")
        else if msg.content.match(/^\!setState\s/gmi)
          newState = msg.content.replace(/^\!setState\s/gmi,"")
          if newState == "online" || newState == "offline" || newState == "dnd" || newState == "idle" || newState == "invisible"
            self.client.setStatus(null, 0, newState)
          else
            msg.channel.sendMessage("That state is not recognised, please use a standard state as specified here https://discordapp.com/developers/docs/topics/gateway#update-status")
        else if msg.content.match(/^setChannelName\s/gmi)
          name = msg.content.replace(/^setChannelName\s/gmi,"")
          msg.channel.setChannelName(name)
        else if msg.content.match(/^\!setUserLimit\s/gmi)
          user_limit = parseInt(msg.content.replace(/^\!setUserLimit\s/gmi,""))
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
        else if msg.content.match(/http(s|):\/\//gmi) && msg.channel.id == "130734377066954752"
          console.log "we got a meme bois"
          setTimeout( () ->
            msg.addReaction("\:upvote\:429449534389616641")
            setTimeout( () ->
              msg.addReaction("\:downvote\:429449638454493187")
            , 500)
          , 500)
        else if msg.content.match(/^\!challenge\s/gmi)
          challenged_user = msg.content.split(/\s/gmi)[1]
          challenged_user_id = challenged_user.replace("<","").replace(">","").replace("@","")
          challenger_user_id = msg.author.id
          #if challenged_user_id != challenger_user_id
          msg.channel.sendMessage("<@"+challenger_user_id+"> has challenged <@"+challenged_user_id+"> to a rock paper scissors duel. Both parties type `!rock`, `!paper` or `!scissors` as a DM to <@169554882674556930>")
          self.challenged[challenged_user_id] = {}
          self.challenged[challenged_user_id] = {
            challenge_in_progress: true,
            challenger: challenger_user_id,
            choice: undefined
          }
          self.challenger[challenger_user_id] ={}
          self.challenger[challenger_user_id] = {
            challenge_in_progress: true,
            challenged: challenged_user_id,
            channel: msg.channel,
            choice: undefined
          }
          console.log "CHALLENGED_USER: "+challenged_user
          #else
          #  msg.channel.sendMessage("Sorry <@"+challenger_user_id+">, you can't challenge yourself :(")
        else if msg.content.match(/^!rock/)
          self.rockPaperScissors(msg, msg.author.id, "rock")
        else if msg.content.match(/^!paper/)
          self.rockPaperScissors(msg, msg.author.id, "paper")
        else if msg.content.match(/^!scissors/)
          self.rockPaperScissors(msg, msg.author.id, "scissors")
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
          #console.log msg.content
          #do nothing, aint a command or anything
        if self.client.channels["432351112616738837"] && msg.author.id != "169554882674556930"
          d = new Date()
          time = "`["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"]` "
          if self.client.guilds[msg.channel.guild_id]
            self.client.channels["432351112616738837"].sendMessage(time + " Message sent by <@"+msg.author.id+"> to the <#"+msg.channel_id+"> channel in the "+self.client.guilds[msg.channel.guild_id].name+" guild")
          else
            self.client.channels["432351112616738837"].sendMessage(time + " Message sent by <@"+msg.author.id+"> to the <#"+msg.channel_id+"> channel (DM)")
    )

    @client.on("messageUpdate", (msg) ->
      if self.client.channels["432351112616738837"] && msg.channel_id != "432351112616738837"
        d = new Date()
        time = "`["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"]` "
        self.client.channels["432351112616738837"].sendMessage(time + " Message `"+msg.id+"` was updated in the <#"+msg.channel_id+"> channel")
    )

    @client.on("messageDelete", (msg_id, channel) ->
      if self.client.channels["432351112616738837"]
        d = new Date()
        time = "`["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"]` "
        desc = time + " Cached Message (`"+msg_id+"`) :link:"
        self.client.channels["432351112616738837"].sendMessage(time + " Message `"+msg_id+"` was deleted from the <#"+channel.id+"> channel in the "+self.client.guilds[channel.guild_id].name+" guild", {
          "embed": {
            "title": desc,
            "url": "https://mb.lolstat.net/api/message_history/"+msg_id,
            "color": 38609
          }
        })
    )

    @client.on("channelCreate", (type, channel) ->
      if self.client.channels["432351112616738837"]
        d = new Date()
        time = "`["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"]` "
        self.client.channels["432351112616738837"].sendMessage(time + " The <#"+channel.id+"> channel was created with channel type `"+type+"`")
    )

    @client.on("channelUpdate", (type, channel) ->
      if self.client.channels["432351112616738837"]
        d = new Date()
        time = "`["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"]` "
        self.client.channels["432351112616738837"].sendMessage(time + " The <#"+channel.id+"> channel was modified")
    )

    @client.on("channelDelete", (type, channel) ->
      if self.client.channels["432351112616738837"]
        d = new Date()
        time = "`["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"]` "
        self.client.channels["432351112616738837"].sendMessage(time + " The channel `"+channel.id+"` was deleted")
    )

    @client.on("channelPinsUpdate", (update) ->
      if self.client.channels["432351112616738837"]
        d = new Date()
        time = "`["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"]` "
        self.client.channels["432351112616738837"].sendMessage(time + " Pins updated in channel <#"+update.channel_id+">")
    )

    @client.on("typingStart", (user_id, channel, timestamp) ->
      if self.client.channels["432351112616738837"]
        d = new Date()
        time = "`["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"]` "
        self.client.channels["432351112616738837"].sendMessage(time + " <@"+user_id+"> has started typing in the <#"+channel.id+"> channel")
    )

    @client.on("userUpdate", (user_id, username, data) ->
      if self.client.channels["432351112616738837"]
        d = new Date()
        time = "`["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"]` "
        self.client.channels["432351112616738837"].sendMessage(time + " <@"+user_id+"> updated their discord profile")
    )

module.exports = motorbotEventHandler