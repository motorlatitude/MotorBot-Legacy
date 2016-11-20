express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
globals = require '../../models/globals.coffee'
request = require('request')
async = require('async')
uid = require('rand-token').uid;

###
  MUSIC ENDPOINT

  https://mb.lolstat.net/api/music/

  Contains Endpoints:
  - play
  - stop
  - pause
  - resume
  - skip
  - prev

  Authentication Required: false
  API Key Required: true
###

router.get("/play", (req, res) ->
  globals.songComplete(true)
  globals.wss.broadcast(JSON.stringify({type: 'playUpdate', status: 'play'}))
  response = {code: 200, status: "OK"}
  res.set(response)
  res.end(JSON.stringify(response))
)

router.get("/stop", (req, res) ->

)

router.get("/pause", (req, res) ->

)

router.get("/resume", (req, res) ->

)

router.get("/skip", (req, res) ->

)

router.get("/prev", (req, res) ->

)