APIConstants = require './APIConstants.coffee'
APIObjects = require './APIObjects.coffee'

class Playlist extends APIObjects

  constructor:(@req) ->
    @database = @req.app.locals.motorbot.database.collection("playlists")

  playlistById: (playlist_id, filter = {}) ->
    self = @
    if Object.keys(filter).length
      if !filter.creator
        filter["creator"] = 1
      filter["_id"] = 0
    else
      filter = {'_id': 0}
    return new Promise((resolve, reject) ->
      self.database.find({id: playlist_id}, filter).toArray((err, results) ->
        if err then reject({error: "DATABASE_ERROR", message: err})
        if results[0]
          if results[0].private
            if self.req.user_id == results[0].creator
              resolve(results[0])
            else
              reject(APIObjects.errors.playlist.private)
          else
            resolve(results[0])
        else resolve({})
      )
    )

module.exports = Playlist