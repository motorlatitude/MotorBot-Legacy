express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
request = require('request')
async = require('async')

###
  USER ENDPOINT

  https://motorbot.io/api/user/

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
        u = results[0]
        formattedResponse = {
          id: u.id
          username: u.username
          discriminator: u.discriminator
          avatar: u.avatar
          guilds: u.guilds
          playlists: u.playlists
          connections: u.connections
        }
        res.type('json')
        res.send(JSON.stringify(formattedResponse))
      else
        res.sendStatus(404)
    )
  else
    res.sendStatus(403)
)

router.get("/playlists", (req, res) ->
  if req.user_id
    userId = req.user_id
    usersCollection = req.app.locals.motorbot.database.collection("users")
    playlistsCollection = req.app.locals.motorbot.database.collection("playlists")

    usersCollection.find({id: userId}).toArray((err, results) ->
      if err then console.log err
      if results[0]
        playlists = results[0].playlists
        total = playlists.length
        next_page = undefined
        prev_page = undefined
        #limit and offset
        #reduce overloading api
        limit = parseInt(req.query.limit) || 20
        offset = parseInt(req.query.offset) || 0
        if limit < 1
          limit = 1
        else if limit > 50
          limit = 50
        if total > (limit + offset) then next_page = "https://motorbot.io/api/user/playlists?limit="+limit+"&offset="+(offset+limit)
        bk = if ((offset - limit) < 0) then 0 else (offset - limit)
        if offset > 0 then prev_page = "https://motorbot.io/api/user/playlists?limit="+limit+"&offset="+bk
        playlists = playlists.slice(offset,(offset + limit))
        playlistsCollection.find({id: {$in: playlists}}).toArray((err, results) ->
          creators = []
          for playlist in results
            playlist.position = playlists.indexOf(playlist.id)
            creators.push(playlist.creator)
          playlists = results
          desiredFields = {}
          if req.query.filter
            for l in req.query.filter.toString().split(",")
              desiredFields[l] = null
          if desiredFields["owner"] == null || !req.query.filter
            usersCollection.find({id: {$in: creators}}).toArray((err, results) ->
              usersArray = {}
              for user in results
                usersArray[user.id] = {username: user.username, discriminator: user.discriminator, id: user.id}
              for playlist in playlists
                playlist["owner"] = usersArray[playlist.creator]
                delete playlist._id
              res.type("json")
              if req.query.filter
                filtered_playlists = []
                for p in playlists
                  k = {}
                  for key, value of desiredFields
                    k[key] = p[key]
                  filtered_playlists.push(k)
                playlists = filtered_playlists
              formattedResponse = {
                items: playlists
                limit: limit
                offset: offset
                total: total
                next: next_page
                prev: prev_page
              }
              res.end(JSON.stringify(formattedResponse))
            )
          else
            filtered_playlists = []
            for p in playlists
              k = {}
              for key, value of desiredFields
                k[key] = p[key]
              filtered_playlists.push(k)
            res.type("json")
            formattedResponse = {
              items: filtered_playlists
              limit: limit
              offset: offset
              total: total
              next: next_page
              prev: prev_page
            }
            res.end(JSON.stringify(formattedResponse))
        )
      else
        res.sendStatus(403)
    )
  else
    res.sendStatus(403)
)

router.patch("/sort/:playlistID/:position", (req, res) ->
  if req.user_id
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
          res.sendStatus(204)
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