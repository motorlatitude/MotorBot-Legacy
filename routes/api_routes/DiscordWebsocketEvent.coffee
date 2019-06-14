express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
request = require('request')
async = require('async')
webshot = require('webshot')

API = require './auth/api.coffee'
objects = require './objects/APIObjects.coffee'
APIObjects = new objects()
utilities = require './objects/APIUtilities.coffee'
APIUtilities = new utilities()

###
  USER ENDPOINT

  https://motorbot.io/api/DiscordWebsocketEvent/

  Contains Endpoints:
  - GET: /{track_id} ->         Get track information

  Authentication Required: false
  API Key Required: true
###

#API Key Checker
router.use(new API())

router.get("/PresenceUpdate", (req, res) ->
  pud = {
    id: req.query.id,
    avatar: req.query.avatar,
    user: req.query.user,
    discriminator: req.query.discriminator,
    status: req.query.status,
    last_status: req.query.last_status,
    last_status_time: req.query.last_status_time,
    device: req.query.device
  }
  res.render("DiscordWebsocketEvents/PresenceUpdate",{user: req.user, PresenceUpdateData: pud})
)

router.get("/RegisterPresenceUpdateUser", (req, res) ->
  pud = {
    id: req.query.id,
    avatar: req.query.avatar,
    user: req.query.user,
    discriminator: req.query.discriminator,
    status: req.query.status
  }
  res.render("DiscordWebsocketEvents/RegisterPresenceUpdateUser",{user: req.user, PresenceUpdateData: pud})
)

router.get("/VoiceUpdate", (req, res) ->
  pud = {
    id: req.query.id,
    avatar: req.query.avatar,
    user: req.query.user,
    discriminator: req.query.discriminator,
    channel: req.query.channel,
    voice_status: req.query.voice_status
  }
  res.render("DiscordWebsocketEvents/VoiceUpdate",{user: req.user, PresenceUpdateData: pud})
)

router.get("/Playing", (req, res) ->
  pud = {
    id: req.query.id,
    avatar: req.query.avatar,
    user: req.query.user,
    discriminator: req.query.discriminator,
    game: req.query.game,
    game_icon: req.query.game_icon,
    application_id: req.query.application_id,
    game_asset_large: req.query.game_asset_large,
    game_state: req.query.game_state,
    game_details: req.query.game_details
  }
  res.render("DiscordWebsocketEvents/Playing",{user: req.user, PresenceUpdateData: pud})
)

router.get("/StoppedPlaying", (req, res) ->
  pud = {
    id: req.query.id,
    avatar: req.query.avatar,
    user: req.query.user,
    discriminator: req.query.discriminator,
    game: req.query.game,
    duration: req.query.duration
  }
  res.render("DiscordWebsocketEvents/StoppedPlaying",{user: req.user, PresenceUpdateData: pud})
)

router.get("/capture", (req, res) ->
  pud = req.body.PresenceUpdateData
  if !pud
    pud = {
      id: "95164972807487488",
      avatar: "a_83116cccec0f8e731bcb3ae19f874d95",
      user: "squírrel",
      discriminator: "2495",
      last_status: "offline",
      last_status_time: "5 mins",
      status: "online",
      device: "Desktop",
      channel: "dev",
      voice_status: "joined",
      game: "Rocket League",
      game_icon: "a",
      game_state: "Working On MotorBot",
      game_details: "Details",
      application_id: "379286085710381999"
      game_asset_large: "351371005538729111",
      duration: "5 minutes"
    }
  options = {
    encoding: "binary",
    captureSelector: ".capture-frame"
  }
  if pud.type == "StatusChange"
    renderStream = webshot("https://motorbot.io/api/DiscordWebsocketEvent/PresenceUpdate?api_key=caf07b8b-366e-44ab-9bda-623f94a9c2df&id="+pud.id+"&avatar="+pud.avatar+"&user="+encodeURIComponent(pud.user)+"&discriminator="+pud.discriminator+"&status="+pud.status+"&device="+pud.device+"&last_status="+pud.last_status+"&last_status_time="+pud.last_status_time, options)
  else if pud.type == "RegisterPresenceUpdateUser"
    renderStream = webshot("https://motorbot.io/api/DiscordWebsocketEvent/RegisterPresenceUpdateUser?api_key=caf07b8b-366e-44ab-9bda-623f94a9c2df&id="+pud.id+"&avatar="+pud.avatar+"&user="+encodeURIComponent(pud.user)+"&discriminator="+pud.discriminator+"&status="+pud.status, options)
  else if pud.type == "VoiceUpdate"
    renderStream = webshot("https://motorbot.io/api/DiscordWebsocketEvent/VoiceUpdate?api_key=caf07b8b-366e-44ab-9bda-623f94a9c2df&id="+pud.id+"&avatar="+pud.avatar+"&user="+encodeURIComponent(pud.user)+"&discriminator="+pud.discriminator+"&voice_status="+pud.voice_status+"&channel="+pud.channel, options)
  else if pud.type == "Playing"
    renderStream = webshot("https://motorbot.io/api/DiscordWebsocketEvent/Playing?api_key=caf07b8b-366e-44ab-9bda-623f94a9c2df&id="+pud.id+"&avatar="+pud.avatar+"&user="+encodeURIComponent(pud.user)+"&discriminator="+pud.discriminator+"&game="+pud.game+"&application_id="+pud.application_id+"&game_asset_large="+pud.game_asset_large+"&game_icon="+pud.game_icon+"&game_state="+pud.game_state+"&game_details="+pud.game_details, options)
  else if pud.type == "StoppedPlaying"
    renderStream = webshot("https://motorbot.io/api/DiscordWebsocketEvent/StoppedPlaying?api_key=caf07b8b-366e-44ab-9bda-623f94a9c2df&id="+pud.id+"&avatar="+pud.avatar+"&user="+encodeURIComponent(pud.user)+"&discriminator="+pud.discriminator+"&game="+pud.game+"&duration="+pud.duration, options)


  res.writeHead(200, [
    "Content-Type", "image/png"
  ])
  renderStream.on('data', (data) ->
    res.write(data.toString('binary'),'binary');
  )

  renderStream.on('close', () ->
    res.end();
  )

  renderStream.on('end', () ->
    res.end();
  )
)


module.exports = router