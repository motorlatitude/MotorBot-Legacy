express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
request = require('request')
async = require('async')

OAuth = require './auth/oauth.coffee'
objects = require './objects/APIObjects.coffee'
APIObjects = new objects()
utilities = require './objects/APIUtilities.coffee'
APIUtilities = new utilities()

###
  USER ENDPOINT

  https://motorbot.io/api/user/

  Contains Endpoints:
  - GET: me
  - GET: playlists

  NON-PUBLIC
  - GET: apps

  Authentication Required: true
  API Key Required: true
###

#API Key & OAuth Checker
router.use(new OAuth())

router.get("/me", (req, res) ->
  if req.user_id
    APIObjects.user(req).userById(req.user_id, {}, (if req.query.karma then true else false)).then((user) ->
      res.type('json')
      u = {}
      if user.id
        u = {
          id: user.id,
          username: user.username,
          discriminator: user.discriminator,
          avatar: user.avatar,
          karma: (if req.query.karma then user.karma else undefined),
          email: user.email || "",
          guilds: user.guilds || [],
          playlists: user.playlists || []
        }
      res.send(JSON.stringify(u))
    ).catch((err) ->
      res.type('json')
      res.status(500).send(JSON.stringify(err))
    )
  else
    res.sendStatus(403)
)

router.get("/playlists", (req, res) ->
  if req.user_id
    APIObjects.user(req).userById(req.user_id).then((user) ->
      if user.playlists
        APIObjects.playlist(req).playlistsByIds(user.playlists).then((playlists) ->
          for playlist in playlists
            pos = user.playlists.indexOf(playlist.id)
            playlist.position = pos
          finalPlaylists = APIObjects.pagination().paginate("/user/playlists", playlists, playlists.length,req.query.offset || 0, req.query.limit|| 20)
          finalPlaylists = APIUtilities.filterResponse(finalPlaylists, req.query.filter)
          res.type("json")
          res.send(JSON.stringify(finalPlaylists))
        ).catch((err) ->
          res.type('json')
          res.status(500).send(JSON.stringify(err))
        )
      else
        res.type('json')
        res.status(500).send(JSON.stringify({error: "USER_ERROR", message: "No playlists found"}))
    )
  else
    res.sendStatus(403)
)

router.patch("/sort/:playlist_id/:position", (req, res) ->
  if req.user_id
    u = APIObjects.user(req)
    u.userById(req.user_id).then((user) ->
      return u.setPlaylistPosition(user.playlists,req.params.playlist_id,req.params.position).then((empty) ->
        #no content returned
        res.sendStatus(204)
      ).catch((err) ->
        res.type('json')
        res.status(500).send(JSON.stringify(err, Object.getOwnPropertyNames(err)))
      )
    ).catch((err) ->
      res.type('json')
      res.status(500).send(JSON.stringify(err, Object.getOwnPropertyNames(err)))
    )
  else
    res.sendStatus(403)
)

###
# /apps - ENDPOINT
# This should not be publicly accessible, make sure that this is only allowed based on certain api keys
#
# Returns api keys and secrets for users with dev access
###
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