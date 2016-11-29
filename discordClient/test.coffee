DiscordClient = require './discordClient.coffee'
youtubeStream = require 'ytdl-core'
keys = require '../keys.json'

dc = new DiscordClient({token: keys.token})

dc.on("ready", (msg) ->
  #console.log "discordClient is ready and sending HB"
)

musicStream = {}
soundboard = {}
yStream = {}

dc.on("message", (msg) ->
  if msg.content.match(/^\!v\sjoin/)
    channelName = msg.content.replace(/^\!v\sjoin\s/,"")
    joined = false
    if channelName
      for channel in dc.guilds[msg.guild_id].channels
        if channel.name == channelName && channel.type == 2
          channel.join()
          joined = true
          break
    if !joined
      for channel in dc.guilds[msg.guild_id].channels
        if channel.type == 2
          channel.join()
          break
  else if msg.content == "!v leave"
    dc.leaveVoiceChannel(msg.guild_id)
  else if msg.content == "!v play"
    if !musicStream[msg.guild_id]
      requestUrl = 'https://www.youtube.com/watch?v=hyPkpXZNbK0'
      yStream[msg.guild_id] = youtubeStream(requestUrl,{quality: 'lowest', filter: 'audioonly'})
      yStream[msg.guild_id].on("error", (e) ->
        console.log("Error Occurred Loading Youtube Video")
      )
      yStream[msg.guild_id].on("info", (info, format) ->
        musicStream[msg.guild_id] = dc.guilds[msg.guild_id].voice.playFromStream(yStream[msg.guild_id])
        musicStream[msg.guild_id].on('ready', () ->
          musicStream[msg.guild_id].play()
        )
        musicStream[msg.guild_id].on("paused", () ->
          if soundboard[msg.guild_id]
            soundboard[msg.guild_id].play()
        )
        musicStream[msg.guild_id].pause()
        musicStream[msg.guild_id].on("streamDone", () ->
          #console.log "stream Done"
          musicStream[msg.guild_id] = undefined
        )
      )
    else
      musicStream[msg.guild_id].play()
  else if msg.content == "!v stop"
    yStream[msg.guild_id].end()
    musicStream[msg.guild_id].stop()
  else if msg.content == "!v pause"
    musicStream[msg.guild_id].pause()
  else if msg.content == "!sb"
    server = msg.guild_id
    soundboard[msg.guild_id] = dc.guilds[server].voice.playFromFile("../soundboard/DootDiddly.mp3")
    soundboard[msg.guild_id].on('ready', () ->
      if musicStream[msg.guild_id]
        musicStream[msg.guild_id].pause()
      else
        soundboard[msg.guild_id].play()
    )
    soundboard[msg.guild_id].on('streamDone', () ->
      #soundboard = null
      if musicStream[msg.guild_id]
        musicStream[msg.guild_id].play()
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
    console.log "Reacting"
    msg.addReaction("ghost")
)

dc.connect()
