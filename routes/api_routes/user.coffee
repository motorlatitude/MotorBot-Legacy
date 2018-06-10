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
        playlists = results[0].playlists
        playlistsCollection = req.app.locals.motorbot.database.collection("playlists")
        playlistsCollection.find({id: {$in: playlists}}).toArray((err, results) ->
          creators = []
          for playlist in results
            playlist.position = playlists.indexOf(playlist.id)
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

router.patch("/sortPlaylists/:playlistID/:position", (req, res) ->
  if req.user
    userId = req.user_id
    usersCollection = req.app.locals.motorbot.database.collection("users")
    usersCollection.find({id: userId}).toArray((err, results) ->
      if err then console.log err
      if results[0]
        playlists = results[0].playlists
        playlists.splice(playlists.indexOf(req.params.playlistID),1)
        playlists.splice(parseInt(req.params.position), 0, req.params.playlistID)
        usersCollection.update({id: userId}, {"$set": {playlists: playlists}}, (err, result) ->
          if err then console.log err
          if result[0]
            res.type("json")
            response = {
              "Response": result[0],
              "ErrorCode": 1,
              "ErrorStatus": "Success",
              "Message": ""
            }
            res.end(JSON.stringify(response))
          else
            res.type("json")
            response = {
              "Response": {},
              "ErrorCode": 4,
              "ErrorStatus": "Empty Response",
              "Message": "Nothing was returned at this endpoint"
            }
            res.end(JSON.stringify(response))
        )
      else
        res.sendStatus(403)
    )
  else
    res.sendStatus(403)
)

router.get("/apps", (req, res) ->
  if req.user_id
    userId = req.user_id
    apiaccessCollection = req.app.locals.motorbot.database.collection("apiaccess")
    apiaccessCollection.find({userId: userId}).toArray((err, results) ->
      if err then console.log err
      res.type("json")
      res.end(JSON.stringify(results))
    )
  else
    res.sendStatus(403)
)

module.exports = router