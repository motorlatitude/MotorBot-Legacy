async = require('async')
cuid = require('cuid')
moment = require 'moment'


APIWebsocket = require './APIWebsocket.coffee'

class Track

  constructor:(@req) ->
    @database = @req.app.locals.motorbot.Database.collection("tracks")

  trackById: (track_id, filter = {}) ->
    self = @
    filter['_id'] = 0
    return new Promise((resolve, reject) ->
      self.database.find({id: track_id}, filter).toArray((err, results) ->
        if err then reject({error: "DATABASE_ERROR", message: err})
        resolve(results[0])
      )
    )

  naturalOrderResults: (resultsFromMongoDB, queryIds) ->
    #Let's build the hashmap
    hashOfResults = resultsFromMongoDB.reduce((prev, curr) ->
      prev[curr.id] = curr
      return prev
    , {})
    return queryIds.map((id) ->
      return hashOfResults[id]
    )

  tracksForIds: (track_ids, filter = {}, sort = {}) ->
    self = @
    filter['_id'] = 0
    return new Promise((resolve, reject) ->
      self.database.find({id: {$in: track_ids}}, filter).sort(sort).toArray((err, results) ->
        if err then reject({error: "DATABASE_ERROR", message: err})
        resolve(self.naturalOrderResults(results, track_ids))
      )
    )

  importTracksFromYoutubeForPlaylist: (videos, importStartTime) ->
    self = @
    APIWebSocket_Connection = new APIWebsocket(self.req)
    return new Promise((resolve, reject) ->
      video_id_list = []
      for spotify_id, video of videos["found"]
        video_id_list.push(video.video_id)
      self.database.find({video_id:{"$in":video_id_list}}).toArray((err, results) ->
        if err
          err.code = "DBERR"
          reject(err)
        else
          #duplicates, do not import
          songs = []
          for song in results
            for spotify_id, video of videos["found"]
              if video.video_id == song.video_id
                song_obj = {
                  id: song.id
                  date_added: moment(video.track_details.added_at.toString()).unix()*1000
                  play_count: 0
                  last_played: undefined
                }
                songs.push(song_obj)
                delete videos["found"][spotify_id]
          #import the rest
          k = 0
          videos = videos["found"]
          async.eachSeries(videos, (track, cb) ->
            v = track
            track_id = cuid()
            artist = {}
            album = {}
            composer = {}
            album_artist = {}
            genres = []
            release_date = undefined
            title = ""
            if v.track_details.track.artists[0]
              id = new Buffer(v.track_details.track.artists[0].name, 'base64')
              artist = {
                name: v.track_details.track.artists[0].name,
                id: id.toString('hex')
              }
            if v.track_details.track.album
              id = new Buffer(v.track_details.track.album.name, 'base64')
              artwork = ""
              if v.track_details.track.album.images[0]
                artwork = v.track_details.track.album.images[0].url
              album = {
                name: v.track_details.track.album.name,
                id: id.toString('hex')
                artwork: artwork
              }
              if v.track_details.track.album.artists[0]
                id = new Buffer(v.track_details.track.album.artists[0].name, 'base64')
                album_artist = {
                  name: v.track_details.track.album.artists[0].name,
                  id: id.toString('hex')
                }
            if v.track_details.track.name && v.track_details.track.name != "" && v.track_details.track.name != " "
              title = v.track_details.track.name
            else
              title = v.video_title
            track_obj = {
              id: track_id,
              type: "youtube",
              video_id: v.video_id,
              video_title: v.video_title,
              spotify_id: v.track_details.spotify_id || "",
              spotify_popularity: v.track_details.spotify_popularity,
              title: v.track_details.track.name || v.video_title,
              artist: artist,
              album: album,
              composer: composer,
              album_artist: album_artist
              genres: genres,
              duration: v.video_duration,
              import_date: new Date().getTime(),
              release_date: release_date,
              track_number: v.track_details.track.track_number || 0,
              disc_number: v.track_details.track.disc_number || 0,
              play_count: 0,
              artwork: album.artwork || "",
              explicit: v.track_details.track.explicit ||false,
              lyrics: "",
              user_id: self.req.user_id,
            }
            self.database.insertOne(track_obj, (err, result) ->
              if err
                console.log err
                cb()
              else
                song_obj = {
                  id: track_obj.id
                  date_added: moment(track.track_details.added_at.toString()).unix()*1000
                  play_count: 0
                  last_played: undefined
                }
                songs.push(song_obj)
                cb()
              APIWebSocket_Connection.send("SPOTIFY_IMPORT", {
                type: "UPDATE",
                start: importStartTime,
                message: "Importing "+(v.track_details.track.name || v.video_title),
                progress: (40*(k/Object.keys(videos).length)+50)/100
              })
              k++
            )
          , (err) ->
            if err then console.log err
            resolve(songs)
          )
      )
    )

module.exports = Track