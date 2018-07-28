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
  res.end("Hi")
)

router.get("/callback", (req, res) ->
  #console.log "twitch callback"
  #console.log req.query
  res.end(req.query["hub.challenge"])
)

router.get("/sample_notification", (req, res) ->
  #console.log "twitch notification"
  thumbnail_url = "https://motorbot.io/twitch%20notification%20layout.png"
  req.app.locals.motorbot.client.channels["409781378100756483"].sendMessage("", {
    embed: {
      image: {
        url: thumbnail_url
        height: 110,
        width: 250
      },
      url: "https://twitch.tv/motorlatitude"
    }
  })
  res.sendStatus(202)
)

router.post("/callback", (req, res) ->
  #console.log "twitch notification"
  #console.log req.body.data
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
        req.app.locals.motorbot.client.channels["409781378100756483"].sendMessage(body.data[0].display_name+" is now live", {
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