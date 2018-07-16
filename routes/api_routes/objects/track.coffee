APIConstants = require './APIConstants.coffee'
APIObjects = require './APIObjects.coffee'

class Track extends APIObjects

  constructor:(@req) ->
    @database = @req.app.locals.motorbot.database.collection("tracks")

  trackById: (track_id, filter = {}) ->


  tracksForIds: (track_ids, filter = {}) ->
    self = @
    filter['_id'] = 0
    return new Promise((resolve, reject) ->
      self.database.find({id: {$in: track_ids}}, filter).toArray((err, results) ->
        if err then reject({error: "DATABASE_ERROR", message: err})
        if results[0]
          resolve(results)
        else
          resolve([])
      )
    )

module.exports = Track