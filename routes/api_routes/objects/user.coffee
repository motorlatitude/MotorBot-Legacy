APIError = require('./APIError.coffee')


class User

  constructor:(@req) ->
    @database = @req.app.locals.motorbot.database.collection("users")

  userById: (user_id, filter = {}) ->
    self = @
    filter['_id'] = 0
    return new Promise((resolve, reject) ->
      self.database.find({id: user_id}, filter).toArray((err, results) ->
        if err
          err.code = "DBERR"
          reject(err)
        if results[0]
          resolve(results[0])
        else
          resolve({})
      )
    )

  setPlaylistPosition: (playlists, playlist_id, position = 1) ->
    self = @
    return new Promise((resolve, reject) ->
      if playlists && playlist_id
        playlists.splice(playlists.indexOf(playlist_id),1)
        playlists.splice(parseInt(position), 0, playlist_id)
        self.database.update({id: self.req.user_id}, {"$set": {playlists: playlists}}, (err, result) ->
          if err
            err.code = "DBERR"
            reject(err)
          else
            resolve({})
        )
      else
        err = new APIError(self, "Missing playlists or playlist_id")
        err.code = "USRERR"
        reject(err)
    )

  addPlaylist: (playlist_id) ->
    self = @
    return new Promise((resolve, reject) ->
      self.database.update({id: self.req.user_id}, {$push: {playlists: playlist_id}}, (err, results) ->
        if err
          err.code = "DBERR"
          reject(err)
        resolve()
      )
    )

  revokeSpotify: () ->
    self = @
    return new Promise((resolve, reject) ->
      self.database.updateOne({id: self.req.user_id},{$unset: {"connections.spotify": ""}}, (err, result) ->
        if err
          err.code = "DBERR"
          reject(err)
        if req.user
          if req.user.connections
            if req.user.connections["spotify"]
              req.user.connections = {}
              delete req.user.connections["spotify"]
        resolve({})
      )
    )

module.exports = User