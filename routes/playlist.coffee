express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
globals = require '../models/globals.coffee'

router.get('/', (req, res, next) ->
  playlistCollection = globals.db.collection("playlist")
  playlistCollection.find({}).sort({timestamp: 1}).toArray((err, results) ->
    if results[0]
      for r in results
        r.formattedTimestamp = globals.convertTimestamp(r.duration)
      playlistCollection.find({status: "playing"}).sort({timestamp: 1}).toArray((err, presult) ->
        title = if presult[0]then presult[0].title else ""
        res.render('playlist',{playlist:results,playing:title})
      )
    else
      res.render('playlist',{playlist:{}})
  )
)

module.exports = router
