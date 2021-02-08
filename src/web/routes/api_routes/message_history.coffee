express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
request = require('request')
async = require('async')

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
  messageCollection = req.app.locals.motorbot.Database.collection("messages")
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

router.get("/user/:user_id", (req, res) ->
  res.type('json')
  messageCollection = req.app.locals.motorbot.Database.collection("messages")
  messageCollection.find({"author.id": req.params.user_id}).toArray((err, results) ->
    if err then console.log err
    if results[0]
      res.send(JSON.stringify({
        query_user_id: req.params.user_id,
        messages_length: results.length,
        messages: results[0]
      }))
    else
      return res.status(404).send({code: 404, status: "Message Not Found"})
  )
)

module.exports = router