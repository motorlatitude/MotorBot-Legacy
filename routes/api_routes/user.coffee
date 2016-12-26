express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
globals = require '../../models/globals.coffee'
request = require('request')
async = require('async')
uid = require('rand-token').uid;

###
  USER ENDPOINT

  https://mb.lolstat.net/api/user/

  Contains Endpoints:
  - playlists

  Authentication Required: true
  API Key Required: true
###

router.get("/playlists", (req, res) ->
  if req.user
    userId = req.user.id
    usersCollection = req.app.locals.motorbot.database.collection("users")
    usersCollection.find({id: userId}).toArray((err, results) ->
      if err then console.log err
      if results[0]
        playlistsCollection = req.app.locals.motorbot.database.collection("playlists")
        playlistsCollection.find({id: {$in: results[0].playlists}}).toArray((err, results) ->
          creators = []
          for playlist in results
            creators.push(playlist.creator)
          playlists = results
          usersCollection.find({id: {$in: creators}}).toArray((err, results) ->
            usersArray = {}
            for user in results
              usersArray[user.id] = {username: user.username, discriminator: user.discriminator}
            for playlist in playlists
              playlist["creatorName"] = usersArray[playlist.creator]
            res.end(JSON.stringify(playlists))
          )
        )
      else
        res.sendStatus(403)
    )
  else
    res.sendStatus(403)
)

module.exports = router