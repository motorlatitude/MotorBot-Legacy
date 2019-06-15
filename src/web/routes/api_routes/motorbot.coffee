express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
request = require('request')
async = require('async')

###
  MOTORBOT ENDPOINT

  https://motorbot.io/api/motorbot/

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
    APIAccessCollection = req.app.locals.motorbot.Database.collection("apiaccess")
    APIAccessCollection.find({key: req.query.api_key}).toArray((err, results) ->
      if err then console.log err
      if results[0]
        return next()
      else
        return res.status(401).send({code: 401, status: "Unauthorized"})
    )
)

router.get("/guilds", (req, res) ->
  res.type('json')
  if req.app.locals.motorbot.Client.guilds
    response = {
      "Response": req.app.locals.motorbot.Client.guilds,
      "ErrorCode": 1,
      "ErrorStatus": "Success",
      "Message": "Ok"
    }
  else
    response = {
      "Response": {},
      "ErrorCode": 2,
      "ErrorStatus": "Not Found",
      "Message": "Connected guilds could not be found"
    }
  res.end(JSON.stringify(response, (key, value) ->
    if key == "client"
      return undefined
    else
      return value
  ))
)

router.get("/channels", (req, res) ->
  res.type('json')
  if req.app.locals.motorbot.Client.channels
    response = {
      "Response": req.app.locals.motorbot.Client.channels,
      "ErrorCode": 1,
      "ErrorStatus": "Success",
      "Message": "Ok"
    }
  else
    response = {
      "Response": {},
      "ErrorCode": 2,
      "ErrorStatus": "Not Found",
      "Message": "Connected channels could not be found"
    }
  res.end(JSON.stringify(response, (key, value) ->
    if key == "client"
      return undefined
    else
      return value
  ))
)

router.get("/channel", (req, res) ->
  res.type('json')
  if req.app.locals.motorbot.Client.voiceConnections["130734377066954752"]
    channelName = req.app.locals.motorbot.Client.voiceConnections["130734377066954752"].channel_name
    res.end(JSON.stringify({channel: channelName}))
  else
    res.end(JSON.stringify({channel: undefined}))
)

module.exports = router