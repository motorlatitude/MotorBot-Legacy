APIObjects = require './APIObjects.coffee'

class Playlist

  constructor:(@req) ->
    self = @
    self.database = @req.app.locals.motorbot.Database.collection("playlists")

  playlistsByIds: (playlist_ids, filter = {}) ->
    self = @
    if Object.keys(filter).length
      if !filter.creator
        filter["creator"] = 1
      filter["_id"] = 0
    else
      filter = {'_id': 0}
    return new Promise((resolve, reject) ->
      self.database.find({id: {$in: playlist_ids}}, filter).toArray((err, results) ->
        if err then reject({error: "DATABASE_ERROR", message: err})
        if results[0]
          p = []
          # Check if playlist is private and do not return if the requesting user is not the creator
          for playlist in results
            if playlist.private
              if playlist.creator == self.req.user_id
                p.push(playlist)
            else
              p.push(playlist)
          resolve(p)
        else resolve({})
      )
    )

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

  importPlaylist: (playlist) ->
    self = @
    return new Promise((resolve, reject) ->
      self.database.insertOne(playlist, (err, result) ->
        if err
          err.code = "DBERR"
          reject(err)
        else
          resolve()
      )
    )

module.exports = Playlist