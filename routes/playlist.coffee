express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
globals = require '../models/globals.coffee'

router.get('/', (req, res, next) ->
  playlistCollection = globals.db.collection("playlist")
  playlistCollection.find({}).sort({timestamp: 1}).toArray((err, results) ->
    if results[0]
      title = ""
      for r in results
        r.formattedTimestamp = globals.convertTimestamp(r.duration)
        r.formattedDiff = globals.millisecondsToStr(new Date().getTime() - r.timestamp)
        if r.status == "playing"
          title = r.title
      res.render('playlist',{playlist:results,playing:title})
    else
      res.render('playlist',{playlist:{}})
  )
)

module.exports = router
