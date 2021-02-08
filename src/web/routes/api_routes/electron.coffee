express = require 'express'
router = express.Router()
fs = require 'fs'
path = require 'path'
keys = require './../../../../keys.json'

###
  ELECTRON ENDPOINT

  https://motorbot.io/api/electron/

  Contains Endpoints:
  - updates/latest

  Authentication Required: false
  API Key Required: false
###

latestRelease = () ->
  dir = "/var/www/motorbot/static/releases/darwin"

  versionsDesc = fs.readdirSync(dir).filter((file) ->
    filePath = path.join(dir, file)
    return fs.statSync(filePath).isDirectory()
  ).reverse()
  return versionsDesc[0]

latestWinRelease = () ->
  dir = "/var/www/motorbot/static/releases/win32"

  versionsDesc = fs.readdirSync(dir).filter((file) ->
    filePath = path.join(dir, file)
    return fs.statSync(filePath).isDirectory()
  ).reverse()
  return versionsDesc[0]

router.get("/updates/latest", (req, res) ->
  version = req.query.v
  latestVersion = latestRelease()
  if version == latestVersion
    res.status(204).end()
  else
    res.json({
      url: keys.baseURL+"/releases/darwin/"+latestVersion+"/MotorBotMusic.zip"
    })
)

router.get("/releases/:release/:version/MotorBotMusic.zip", (req, res) ->
  ###
  res.writeHead(200, {
    'Content-Type': 'application/zip',
    'Content-disposition': 'attachment; filename=MotorBotMusic.zip'
  })###
  res.download("/var/www/motorbot/releases/"+req.params.release+"/"+req.params.version+"/MotorBotMusic.zip")
)

router.get("/updates/latest/win32", (req, res) ->
  latestVersion = latestWinRelease()
  ###
  res.writeHead(200, {
    'Content-Type': 'application/zip',
    'Content-disposition': 'attachment; filename=MotorBotMusic.zip'
  })###
  res.redirect("/releases/win32/"+latestVersion+"/MotorBotMusic")
)

module.exports = router