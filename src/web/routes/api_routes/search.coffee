express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
request = require('request')
async = require('async')

utilities = require './objects/APIUtilities.coffee'
APIUtilities = new utilities()
objects = require './objects/APIObjects.coffee'
APIObjects = new objects()

###
  QUEUE ENDPOINT

  https://motorbot.io/api/search

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
    APIAccessCollection = req.app.locals.motorbot.Database.collection("apiaccess")
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
  tracksCollection = req.app.locals.motorbot.Database.collection("tracks")
  playlistsCollection = req.app.locals.motorbot.Database.collection("playlists")
  regexQuery = new RegExp(".*"+req.query.q+".*","gmi")
  console.log regexQuery.toString()
  response = {
    tracks: null,
    playlists: null
  }
  async.parallel([
    (cb) ->
      tracksCollection.find({$or: [{title: regexQuery},{"album.name": regexQuery},{"artist.name": regexQuery}]}).sort({play_count: -1}).toArray((err, results) ->
        if err
          cb(err)
        else
          limit = parseInt(req.query.limit) || 100
          offset = parseInt(req.query.offset) || 0
          if limit < 1
            limit = 1
          else if limit > 100
            limit = 100
          response["tracks"] = APIObjects.pagination().paginate("/search?q="+req.query.q, results, results.length, offset, limit)
          cb()
      )
    , (cb) ->
      playlistsCollection.find({$and: [{$or: [{name: regexQuery},{"description": regexQuery}]}, {private: false}]}).toArray((err, results) ->
        if err
          cb(err)
        else
          limit = parseInt(req.query.limit) || 100
          offset = parseInt(req.query.offset) || 0
          if limit < 1
            limit = 1
          else if limit > 100
            limit = 100
          response["playlists"] = APIObjects.pagination().paginate("/search?q="+req.query.q, results, results.length, offset, limit)
          cb()
      )
  ], (err) ->
    if err
      console.log err
      res.sendStatus(500)
    else
      res.type("json")
      responseObject = response
      finalSearch = APIUtilities.filterResponse(responseObject,req.query.filter)
      res.send(JSON.stringify(finalSearch))
  )
)

module.exports = router