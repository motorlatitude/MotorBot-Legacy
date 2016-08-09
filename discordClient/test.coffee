DiscordClient = require './discordClient.coffee'
youtubeStream = require 'ytdl-core'

dc = new DiscordClient({token: "MTY5NTU0ODgyNjc0NTU2OTMw.CfAmNQ.WebsSsEexNlFWaNc2u54EP-hIX0"})

dc.on("ready", (msg) ->
  console.log "discordClient is ready and sending HB"
)

musicStream = null

dc.on("message", (msg, channel_id, user_id, raw) ->
  if msg == "!v"
    dc.joinVoiceChannel("194904787924418561")
  else if msg == "!v play"
    requestUrl = 'http://youtube.com/watch?v=bwmSjveL3Lc'
    yStream = youtubeStream(requestUrl,{quality: 'lowest', filter: 'audioonly'})
    yStream.on("error", (e) ->
      console.log("Error Occured Loading Youtube Video")
    )
    yStream.on("info", (info, format) ->
      musicStream = dc.internals.servers["130734377066954752"].voice.playFromStream(yStream)
      musicStream.on('ready', () ->
        dc.internals.servers["130734377066954752"].voice.play(musicStream)
      )
    )
)

dc.connect() #must go last
