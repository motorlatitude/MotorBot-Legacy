DiscordClient = require './discordClient.coffee'

dc = new DiscordClient({token: "MTY5NTU0ODgyNjc0NTU2OTMw.CfAmNQ.WebsSsEexNlFWaNc2u54EP-hIX0"})

dc.on("ready", (msg) ->
  console.log "discordClient is ready and sending HB"
)

dc.on("message", (msg, channel_id, user_id, raw) ->
  if msg == "!v"
    dc.joinVoiceChannel("194904787924418561")
)

dc.connect() #must go last
