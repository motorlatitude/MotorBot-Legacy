express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
globals = require '../../models/globals.coffee'
request = require('request')
async = require('async')
uid = require('rand-token').uid;

###
  MESSAGE_HISTORY ENDPOINT

  https://motorbot.io/api/message_history

  Contains Endpoints:
  - channel

  Authentication Required: false
  API Key Required: false
###

router.get("/:message_id", (req, res) ->
  res.type('json')
  messageCollection = req.app.locals.motorbot.database.collection("messages")
  messageCollection.find({id: req.params.message_id}).toArray((err, results) ->
    if err then console.log err
    if results[0]
      res.send(JSON.stringify({
        query_message_id: req.params.message_id,
        message: results[0]
      }))
    else
      return res.status(404).send({code: 404, status: "Message Not Found"})
  )
)

module.exports = router