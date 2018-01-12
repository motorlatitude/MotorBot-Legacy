express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
globals = require '../../models/globals.coffee'
request = require('request')
async = require('async')
uid = require('rand-token').uid;

###
  QUEUE ENDPOINT

  https://mb.lolstat.net/api/search

  Contains Endpoints:
  - GET: ?q=search+term                                            - search

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

router.get("/", (req, res) ->
  res.type('json')
  tracksCollection = req.app.locals.motorbot.database.collection("tracks")
  tracksCollection.find({$text: {$search: req.query.q}}).toArray((err, results) ->
    if err
      res.sendStatus(500)
    else
      res.end(JSON.stringify(results))
  )
)

module.exports = router