express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
globals = require '../models/globals.coffee'
request = require('request')
async = require('async')
uid = require('rand-token').uid

###
  TWITCH CALLBACK
###

recieved_ids = []

router.get("/", (req, res) ->
  console.log "twitch callback"
  res.end("Hi")
)

router.get("/callback", (req, res) ->
  console.log "twitch callback"
  console.log req.query
  res.end(req.query["hub.challenge"])
)

router.post("/callback", (req, res) ->
  console.log "twitch notification"
  console.log req.body.data
  for notification in req.body.data
    notification_recieved = false
    for id in recieved_ids
      if id == notification.id
        notification_recieved = true
    if !notification_recieved
      recieved_ids.push(notification.id)
      console.log notification
      thumbnail_url = notification.thumbnail_url.replace("{width}","128").replace("{height}","80")
      request.get({
        url: "https://api.twitch.tv/helix/users?id="+notification.user_id
        headers: {
          "Client-ID": "1otsv80onfatqfom7ny85js3vakssl"
        },
        json: true
      }, (error, httpResponse, body) ->
        req.app.locals.motorbot.client.channels["130734377066954752"].sendMessage(body.data[0].display_name+" is now live", {
          embed: {
            title: notification.title,
            description: notification.viewer_count+" watching"
            type: "rich",
            color: 4929148,
            thumbnail: {
              url: thumbnail_url
              height: 80,
              width: 128
            },
            url: "https://twitch.tv/"+body.data[0].login
          }
        })
      )
  res.sendStatus(202)
)

module.exports = router