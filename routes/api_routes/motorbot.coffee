express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
globals = require '../../models/globals.coffee'
request = require('request')
async = require('async')
uid = require('rand-token').uid;

###
  MOTORBOT ENDPOINT

  https://mb.lolstat.net/api/motorbot/

  Contains Endpoints:
  - channel

  Authentication Required: false
  API Key Required: true
###

#API Key checker
router.use((req, res, next) ->
  if !req.query.api_key
    return res.status(401).send({code: 401, status: "No API Key Supplied"})
  else
    APIAccessCollection = req.app.locals.motorbot.database.collection("apiaccess")
    APIAccessCollection.find({key: req.query.api_key}).toArray((err, results) ->
      if err then console.log err
      if results[0]
        return next()
      else
        return res.status(401).send({code: 401, status: "Unauthorized"})
    )
)

router.get("/channel", (req, res) ->
  res.type('json')
  if req.app.locals.motorbot.voiceConnections["130734377066954752"]
    channelName = req.app.locals.motorbot.voiceConnections["130734377066954752"].channel_name
    res.end(JSON.stringify({channel: channelName}))
  else
    res.end(JSON.stringify({channel: undefined}))
)

module.exports = router