DiscordClient = require './discordClient.coffee'
youtubeStream = require 'ytdl-core'

dc = new DiscordClient({token: "MTY5NTU0ODgyNjc0NTU2OTMw.CfAmNQ.WebsSsEexNlFWaNc2u54EP-hIX0"})

dc.on("ready", (msg) ->
  console.log "discordClient is ready and sending HB"
)

musicStream = null
soundboard = null

dc.on("message", (msg, channel_id, user_id, raw) ->
  if msg == "!v"
    dc.joinVoiceChannel("194904787924418561")
  else if msg == "!v leave"
    dc.leaveVoiceChannel("130734377066954752")
  else if msg == "!v play"
    if musicStream == null
      requestUrl = 'http://youtube.com/watch?v=bwmSjveL3Lc'
      yStream = youtubeStream(requestUrl,{quality: 'lowest', filter: 'audioonly'})
      yStream.on("error", (e) ->
        console.log("Error Occured Loading Youtube Video")
      )
      yStream.on("info", (info, format) ->
        musicStream = dc.internals.servers["130734377066954752"].voice.playFromStream(yStream)
        musicStream.on('ready', () ->
          musicStream.play()
        )
        musicStream.on("streamDone", () ->
          console.log "stream Done"
          musicStream = null
        )
      )
    else
      musicStream.play()
  else if msg == "!v stop"
    musicStream.stop()
  else if msg == "!v pause"
    musicStream.pause()
  else if msg == "!sb"
    return setTimeout(() ->
      soundboard = dc.internals.servers["130734377066954752"].voice.playFromFile("/var/www/motorbot/soundboard/kled.mp3")
      soundboard.on('ready', () ->
        if musicStream
          musicStream.pause()
          musicStream.on("paused", () ->
            soundboard.play()
          )
        else
          soundboard.play()
      )
      soundboard.on('streamDone', () ->
        soundboard.destroy()
        soundboard = null
        if musicStream
          musicStream.play()
      )
    , 5000)
)

dc.connect()
