request = require('request')
cuid = require('cuid')

APIError = require('./APIError.coffee')

class SpotifyPlaylists

  constructor:(@req, @res) ->

  getPlaylists: (offset, limit, playlists, cb) ->
    self = @
    if self.req.user
      if self.req.user.connections
        if self.req.user.connections["spotify"]
          request({
            url: "https://api.spotify.com/v1/me/playlists?offset="+offset+"&limit="+limit,
            json: true,
            'auth': {
              'bearer': self.req.user.connections["spotify"].access_token
            }
          }, (err, httpResponse, data) ->
            if err then return self.res.status(500).send({code: "SPTFYERR", message: "Request Failure", error: err})
            if data.items
              playlists = playlists.concat(data.items);
            if data.next
              self.getPlaylists(offset+limit, limit, playlists, cb)
            else
              if typeof cb == "function"
                cb(playlists)
          )
        else
          self.res.status(500).send({code: "USRERR", message: "User does not have spotify credentials configured correctly"})
      else
        self.res.status(500).send({code: "USRERR", message: "User does not have spotify credentials configured correctly"})
    else
      self.res.status(403).send({code: "USRERR", message: "User Not Signed In"})

  getPlaylistTracks: (owner_id, playlist_id) ->
    self = @
    return new Promise((resolve, reject) ->
      tracks = []
      playlist = {}
      fetch = (url) ->
        request({
            url: url,
            json: true,
            'auth': {
              'bearer': self.req.user.connections["spotify"].access_token
            }
          }, (err, httpResponse, data) ->
          if err then reject(err)
          if data.tracks
            #initiate playlist object following standardized mongo playlist object
            artwork = ""
            if data.images[0]
              artwork = data.images[0].url
            playlist= {
              id: cuid()
              type: "spotify playlist"
              name: data.name
              description: data.description || ""
              songs: []
              creator: self.req.user_id
              create_date: new Date().getTime()
              followers: [self.req.user_id]
              artwork: artwork
              private: !data.public || false
              collaborative: data.collaborative || false
            }
            if data.tracks.items
              #loop over available tracks
              for track in data.tracks.items
                tracks[track.track.id ||cuid()] = track
              if data.tracks.next
                #playlist has more than {{track limit}} songs, further request required
                fetch(data.tracks.next)
              else
                #playlist has less than {{track limit}} songs and import complete
                resolve({playlist: playlist, tracks: tracks})
            else
              #no tracks in this playlist, import only playlist object
              resolve({playlist: playlist, tracks: tracks})
          else if data.items
            #loop over available tracks
            for track in data.items
              track.spotify_id = track.track.id
              tracks[track.track.id || cuid()] = track
            if data.next
              #playlist has more than {{track limit}} songs, further request required
              fetch(data.next)
            else
              #fetched all songs, resolve
              resolve({playlist: playlist, tracks: tracks})
          else
            err = new APIError(self, "No playlist found with the following parameters;\nowner_id:"+owner_id+"\nplaylist_id:"+playlist_id)
            err.code = "SPTFYERR"
            reject(err)
        )
      # start fetch cycle
      fetch("https://api.spotify.com/v1/users/"+owner_id+"/playlists/"+playlist_id)
    )

module.exports = SpotifyPlaylists