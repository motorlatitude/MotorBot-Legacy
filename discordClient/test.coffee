DiscordClient = require './discordClient.coffee'
youtubeStream = require 'ytdl-core'
keys = require '../keys.json'

dc = new DiscordClient({token: keys.token})

dc.on("ready", (msg) ->
  console.log "discordClient is ready and sending HB"
)

musicStream = null
soundboard = null
yStream = null

dc.on("message", (msg, channel_id, user_id, raw) ->
  if msg == "!v"
    dc.joinVoiceChannel("130734378656464896") #general: 130734378656464896; dev: 194904787924418561
  else if msg == "!v leave"
    dc.leaveVoiceChannel("130734377066954752")
  else if msg == "!v play"
    if musicStream == null
      requestUrl = 'https://www.youtube.com/watch?v=hyPkpXZNbK0'
      yStream = youtubeStream(requestUrl,{quality: 'lowest', filter: 'audioonly'})
      yStream.on("error", (e) ->
        console.log("Error Occurred Loading Youtube Video")
      )
      yStream.on("info", (info, format) ->
        musicStream = dc.internals.servers["130734377066954752"].voice.playFromStream(yStream)
        musicStream.on('ready', () ->
          musicStream.play()
        )
        musicStream.on("paused", () ->
          console.log("MUSIC STREAM PAUSED")
          if soundboard
            soundboard.play()
        )
        musicStream.pause()
        musicStream.on("streamDone", () ->
          console.log "stream Done"
          musicStream = null
        )
      )
    else
      musicStream.play()
  else if msg == "!v stop"
    yStream.end()
    musicStream.stop()
  else if msg == "!v pause"
    musicStream.pause()
  else if msg == "!sb"
    soundboard = dc.internals.servers["130734377066954752"].voice.playFromFile("../soundboard/DootDiddly.mp3")
    soundboard.on('ready', () ->
      console.log("SOUNDBOARD READY");
      if musicStream
        musicStream.pause()
      else
        soundboard.play()
    )
    soundboard.on('streamDone', () ->
      #soundboard = null
      if musicStream
        musicStream.play()
    )
)

dc.connect()
