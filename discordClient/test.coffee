DiscordClient = require './discordClient.coffee'
youtubeStream = require 'ytdl-core'
keys = require '../keys.json'
Table = require('cli-table')

dc = new DiscordClient({token: keys.token})

dc.on("ready", (msg) ->
  #console.log "discordClient is ready and sending HB"
)

songList = ["https://www.youtube.com/watch?v=CkQGvs-SYbk","https://www.youtube.com/watch?v=p7_qZSYAxoQ","https://www.youtube.com/watch?v=vmF64VaquYQ","https://www.youtube.com/watch?v=cyBEQD6065s","https://www.youtube.com/watch?v=gb2ZEzqHH2g","https://www.youtube.com/watch?v=P48RCKp6iVU"]

musicPlayers = {}
soundboard = {}
yStream = {}
voiceConnections = {}

playNextTrack = (guild_id) ->
  requestUrl = songList.shift()
  if requestUrl
    yStream[guild_id] = youtubeStream(requestUrl,{quality: 'lowest', filter: 'audioonly'})
    yStream[guild_id].on("error", (e) ->
      console.log("Error Occurred Loading Youtube Video")
    )
    yStream[guild_id].on("info", (info, format) ->
      voiceConnections[guild_id].playFromStream(yStream[guild_id]).then((audioPlayer) ->
        musicPlayers[guild_id] = audioPlayer
        musicPlayers[guild_id].on('ready', () ->
          musicPlayers[guild_id].play()
        )
        musicPlayers[guild_id].on("paused", () ->
          if soundboard[guild_id]
            soundboard[guild_id].play()
        )
        #musicPlayers[guild_id].pause()
        musicPlayers[guild_id].on("streamDone", () ->
          musicPlayers[guild_id] = undefined
          playNextTrack(guild_id)
        )
      )
    )

dc.on("message", (msg) ->
  if msg.content.match(/^\!v\sjoin/)
    channelName = msg.content.replace(/^\!v\sjoin\s/,"")
    joined = false
    if channelName
      for channel in dc.guilds[msg.guild_id].channels
        if channel.name == channelName && channel.type == 2
          channel.join().then((VoiceConnection) ->
            voiceConnections[msg.guild_id] = VoiceConnection
          )
          joined = true
          break
    if !joined
      for channel in dc.guilds[msg.guild_id].channels
        if channel.type == 2
          channel.join().then((VoiceConnection) ->
            voiceConnections[msg.guild_id] = VoiceConnection
          )
          break
  else if msg.content == "!v leave"
    dc.leaveVoiceChannel(msg.guild_id)
  else if msg.content == "!v play"
    if !musicPlayers[msg.guild_id]
      playNextTrack(msg.guild_id)
    else
      musicPlayers[msg.guild_id].play()
  else if msg.content == "!v play force"
    yStream[msg.guild_id].end()
    musicPlayers[msg.guild_id].stop()
    musicPlayers[msg.guild_id] = undefined
    playNextTrack(msg.guild_id)
  else if msg.content == "!v stop"
    yStream[msg.guild_id].end()
    musicPlayers[msg.guild_id].stop()
  else if msg.content == "!v pause"
    musicPlayers[msg.guild_id].pause()
  else if msg.content == "!sb"
    if !soundboard[msg.guild_id]
      voiceConnections[msg.guild_id].playFromFile("../soundboard/DootDiddly.mp3").then((audioPlayer) ->
        soundboard[msg.guild_id] = audioPlayer
        soundboard[msg.guild_id].on('ready', () ->
          if musicPlayers[msg.guild_id]
            musicPlayers[msg.guild_id].pause()
          else
            soundboard[msg.guild_id].play()
        )
        soundboard[msg.guild_id].on('streamDone', () ->
          soundboard[msg.guild_id] = undefined
          if musicPlayers[msg.guild_id]
            musicPlayers[msg.guild_id].play()
        )
      )
  else if msg.content == "!ping"
    msg.channel.sendMessage("pong!")
  else if msg.content == "!dev client status"
    server = msg.guild_id
    content = "Motorbot is connected to your gateway server on **"+dc.internals.gateway+"** with an average ping of **"+Math.round(dc.internals.avgPing*100)/100+"ms**. The last ping was **"+dc.internals.pings[dc.internals.pings.length-1]+"ms**."
    msg.channel.sendMessage(content)
  else if msg.content.match(/^\!dev voice status/)
    additionalParams = msg.content.replace(/^\!dev voice status\s/gmi,"")
    server = msg.guild_id
    if dc.voiceHandlers[server]
      bytes = dc.voiceHandlers[server].bytesTransmitted
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
      content = "Motorbot is connected to your voice server on **"+dc.voiceHandlers[server].endpoint+"** with an average ping of **"+Math.round(dc.voiceHandlers[server].avgPing*100)/100+"ms**. The last ping was **"+dc.voiceHandlers[server].pings[dc.voiceHandlers[server].pings.length-1]+"ms**.\n"
      if additionalParams == "detailed"
        table = new Table({
          #head: ["Parameter","Value"]
          style: {'padding-left':1, 'padding-right':1, head:[], border:[]}
        })
        avgPing = (Math.round(dc.voiceHandlers[server].avgPing*100)/100)
        connectedTime = (Math.round(((new Date().getTime() - dc.voiceHandlers[server].connectTime)/1000)*10)/10)
        table.push(["Endpoint",dc.voiceHandlers[server].endpoint])
        table.push(["Local Port",dc.voiceHandlers[server].localPort])
        table.push(["Average Ping",avgPing+"ms"])
        table.push(["Last Ping",dc.voiceHandlers[server].pings[dc.voiceHandlers[server].pings.length-1]+"ms"])
        table.push(["Heartbeats Sent",dc.voiceHandlers[server].pings.length])
        table.push(["Bytes Transmitted",bytes+" "+units])
        table.push(["Sequence",dc.voiceHandlers[server].sequence])
        table.push(["Timestamp",dc.voiceHandlers[server].timestamp])
        table.push(["Source ID (ssrc)",dc.voiceHandlers[server].ssrc])
        table.push(["mode","xsalsa20_poly1305"])
        table.push(["User ID",dc.voiceHandlers[server].user_id])
        table.push(["Session",dc.voiceHandlers[server].session_id])
        table.push(["Token",dc.voiceHandlers[server].token])
        table.push(["Connected",connectedTime+"s"])
        content = "```markdown\n"+table.toString()+"\n```"
        if !dc.voiceHandlers[server].pings[0]
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
    dc.channels["194904787924418561"].setUserLimit(user_limit)
)

dc.connect()
