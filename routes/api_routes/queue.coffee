express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
globals = require '../../models/globals.coffee'
request = require('request')
async = require('async')
uid = require('rand-token').uid;

###
  QUEUE ENDPOINT

  https://mb.lolstat.net/api/queue/

  Contains Endpoints:
  - /

  Authentication Required: false
  API Key Required: true
###

router.get("/", (req, res) ->
  res.type('json')
  songQueueCollection = req.app.locals.motorbot.database.collection("songQueue")
  if globals.randomPlayback
    songQueueCollection.find({}).sort({randId: 1}).toArray((err, results) ->
      if err
        res.sendStatus(500)
      else
        res.end(JSON.stringify(results))
    )
  else
    songQueueCollection.find({}).toArray((err, results) ->
      if err
        res.sendStatus(500)
      else
        res.end(JSON.stringify(results))
    )
)

module.exports = router