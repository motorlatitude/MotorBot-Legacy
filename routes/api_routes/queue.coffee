express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
request = require('request')
async = require('async')
uid = require('rand-token').uid;

###
  QUEUE ENDPOINT

  https://motorbot.io/api/queue/

  Contains Endpoints:
  - GET: /                                            - get queue
  - PUT: /song/{song_id}/playlist/{playlist_id}       - add song to queue

  Authentication Required: false
  API Key Required: true
###

#API Key checker
router.use((req, res, next) ->
  if !req.query.api_key
    return res.status(401).send({code: 401, status: "No API Key Supplied"})
  else
    APIAccessCollection = req.app.locals.motorbot.database.collection("apiaccess")
    APIAccessCollection.find({key: req.query.api_key}).toArray((err, results) ->
      if err then console.log err
      if results[0]
        return next()
      else
        return res.status(401).send({code: 401, status: "Unauthorized"})
    )
)

router.put("/song/:song_id/playlist/:playlist_id", (req, res) ->
  song_id = req.params.song_id
  playlist_id = req.params.playlist_id
  tracksCollection = req.app.locals.motorbot.database.collection("tracks")
  songQueueCollection = req.app.locals.motorbot.database.collection("songQueue")
  res.type("json")
  tracksCollection.find({id: song_id}).toArray((err, results) ->
    if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
    if results[0]
      song = results[0]
      song.status = "queued"
      song.songId = song.id.toString()
      song._id = undefined
      song.playlistId = playlist_id
      songQueueCollection.insert(song, (err, results) ->
        if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
        res.send(song)
        if !req.app.locals.motorbot.musicPlayers["130734377066954752"]
          req.app.locals.motorbot.nextSong()
      )
    else
      return res.status(404).send({code: 404, status: "Song Not Found"})
  )
)

router.get("/", (req, res) ->
  res.type('json')
  songQueueCollection = req.app.locals.motorbot.database.collection("songQueue")
  songQueueCollection.find({}).toArray((err, results) ->
    if err
      res.sendStatus(500)
    else
      res.end(JSON.stringify(results))
  )
)

module.exports = router