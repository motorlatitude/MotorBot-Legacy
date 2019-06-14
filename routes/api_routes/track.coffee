express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
request = require('request')
async = require('async')

API = require './auth/api.coffee'
objects = require './objects/APIObjects.coffee'
APIObjects = new objects()
utilities = require './objects/APIUtilities.coffee'
APIUtilities = new utilities()

###
  USER ENDPOINT

  https://motorbot.io/api/track/

  Contains Endpoints:
  - GET: /{track_id} ->         Get track information

  Authentication Required: false
  API Key Required: true
###

#API Key Checker
router.use(new API())

router.get("/:track_id", (req, res) ->
  APIObjects.track(req).trackById(req.params.track_id).then((track) ->
    t = APIUtilities.filterResponse(track, req.query.filter)
    res.type('json')
    res.send(JSON.stringify(t))
  ).catch((err) ->
    res.type('json')
    res.status(500).send(JSON.stringify(err, Object.getOwnPropertyNames(err)))
  )
)


module.exports = router