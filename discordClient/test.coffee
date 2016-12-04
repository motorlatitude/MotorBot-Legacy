DiscordClient = require './discordClient.coffee'
youtubeStream = require 'ytdl-core'
keys = require '../keys.json'

dc = new DiscordClient({token: keys.token})

dc.on("ready", (msg) ->
  #console.log "discordClient is ready and sending HB"
)

musicPlayers = {}
soundboard = {}
yStream = {}
voiceConnections = {}

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
    if !musicStream[msg.guild_id]
      requestUrl = 'https://www.youtube.com/watch?v=4emYaDbaJ8w'
      yStream[msg.guild_id] = youtubeStream(requestUrl,{quality: 'lowest', filter: 'audioonly'})
      yStream[msg.guild_id].on("error", (e) ->
        console.log("Error Occurred Loading Youtube Video")
      )
      yStream[msg.guild_id].on("info", (info, format) ->
        voiceConnections[msg.guild_id].playFromStream(yStream[msg.guild_id]).then((audioPlayer) ->
          musicPlayers[msg.guild_id] = audioPlayer
        )
        musicPlayers[msg.guild_id].on('ready', () ->
          musicPlayers[msg.guild_id].play()
        )
        musicPlayers[msg.guild_id].on("paused", () ->
          if soundboard[msg.guild_id]
            soundboard[msg.guild_id].play()
        )
        musicPlayers[msg.guild_id].pause()
        musicPlayers[msg.guild_id].on("streamDone", () ->
          #console.log "stream Done"
          musicPlayers[msg.guild_id] = undefined
        )
      )
    else
      musicPlayers[msg.guild_id].play()
  else if msg.content == "!v stop"
    yStream[msg.guild_id].end()
    musicPlayers[msg.guild_id].stop()
  else if msg.content == "!v pause"
    musicPlayers[msg.guild_id].pause()
  else if msg.content == "!sb"
    voiceConnections[msg.guild_id].playFromFile("../soundboard/DootDiddly.mp3").then((audioPlayer) ->
      soundboard[msg.guild_id] = audioPlayer
    )
    soundboard[msg.guild_id].on('ready', () ->
      if musicPlayers[msg.guild_id]
        musicPlayers[msg.guild_id].pause()
      else
        soundboard[msg.guild_id].play()
    )
    soundboard[msg.guild_id].on('streamDone', () ->
      #soundboard = null
      if musicPlayers[msg.guild_id]
        musicPlayers[msg.guild_id].play()
    )
  else if msg.content == "!ping"
    msg.channel.sendMessage("pong!")
  else if msg.content == "!dev client status"
    server = msg.guild_id
    content = "Motorbot is connected to your gateway server on **"+dc.internals.gateway+"** with an average ping of **"+Math.round(dc.internals.avgPing*100)/100+"ms**. The last ping was **"+dc.internals.pings[dc.internals.pings.length-1]+"ms**."
    msg.channel.sendMessage(content)
  else if msg.content == "!dev voice status"
    server = msg.guild_id
    content = "Motorbot is connected to your voice server on **"+dc.guilds[server].voice.endpoint+"** with an average ping of **"+Math.round(dc.guilds[server].voice.avgPing*100)/100+"ms**. The last ping was **"+dc.guilds[server].voice.pings[dc.guilds[server].voice.pings.length-1]+"ms**."
    msg.channel.sendMessage(content)
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
)

dc.connect()
