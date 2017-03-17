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
  - me
  - playlists

  Authentication Required: true
  API Key Required: true
###

#API Key & OAuth Checker
router.use((req, res, next) ->
  if !req.query.api_key
    return res.status(401).send({code: 401, status: "No API Key Supplied"})
  else
    APIAccessCollection = req.app.locals.motorbot.database.collection("apiaccess")
    APIAccessCollection.find({key: req.query.api_key}).toArray((err, results) ->
      if err then console.log err
      if results[0]
        client_id = results[0].id
        if req.headers["authorization"]
          bearerHeader = req.headers["authorization"]
          if typeof bearerHeader != 'undefined'
            bearer = bearerHeader.split(" ")
            bearerToken = bearer[1]
            console.log bearerToken
            accessTokenCollection = req.app.locals.motorbot.database.collection("accessTokens")
            accessTokenCollection.find({value: bearerToken}).toArray((err, result) ->
              if err then console.log err
              if result[0]
                if client_id == result[0].clientId
                  req.user_id = result[0].userId
                  req.client_id = result[0].clientId
                  return next()
                else
                  return res.status(401).send({code: 401, status: "Client Unauthorized"})
              else
                return res.status(401).send({code: 401, status: "Unknown Access Token"})
            )
          else
            return res.status(401).send({code: 401, status: "No Token Supplied"})
        else
          return res.status(401).send({code: 401, status: "No Token Supplied"})
      else
        return res.status(401).send({code: 401, status: "Unauthorized"})
    )
)

router.get("/me", (req, res) ->
  if req.user_id
    usersCollection = req.app.locals.motorbot.database.collection("users")
    usersCollection.find({id: req.user_id}).toArray((err, results) ->
      if err then res.sendStatus(500)
      if results[0]
        res.type('json')
        res.send(JSON.stringify(results[0]))
      else
        res.sendStatus(404)
    )
  else
    res.sendStatus(429)
)

router.get("/playlists", (req, res) ->
  if req.user_id
    userId = req.user_id
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
            res.type("json")
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