express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
request = require('request')
async = require('async')
uid = require('uuid/v4')
passport = require 'passport'
moment = require 'moment'
SpotifyStrategy = require('passport-spotify').Strategy

OAuth = require './auth/oauth.coffee'
PassportSpotify = require './auth/PassportSpotify.coffee'
SpotifyRefreshAccessToken = require './auth/SpotifyRefreshAccessToken.coffee'

objects = require './objects/APIObjects.coffee'
APIObjects = new objects()
utilities = require './objects/APIUtilities.coffee'
APIUtilities = new utilities()
APIWebsocket = require './objects/APIWebsocket.coffee'
APIError = require './objects/APIError.coffee'

###
  SPOTIFY ENDPOINT

  https://motorbot.io/api/spotify/

  Contains Endpoints:
  - GET / ->                                                              authentication with user
  - GET /callback ->                                                      spotify oauth callback

  - GET /revoke ->                                                        *, **: revoke spotify and MotorBot account connection
  - PUT /playlist/:spotify_playlist_id/owner/:spotify_owner_id ->         *, **: import spotify playlist

  *  Authentication Required: true
  ** API Key Required: true
###

passport = new PassportSpotify()

router.get("/", passport.authenticate('spotify', {scope: ['playlist-read-private', 'playlist-read-collaborative', 'user-read-recently-played', 'user-read-private user-top-read'], session: false}), (req, res) ->
  res.type('json')
)

router.get("/callback", passport.authenticate('spotify', { failureRedirect: 'https://motorbot.io/dashboard/account/connections', session: false }), (req, res) ->
  res.redirect("https://motorbot.io/dashboard/account/connections")
)

router.get("/playlists", new OAuth(), new SpotifyRefreshAccessToken(), (req, res) ->
  res.type("json")
  APIObjects.spotifyPlaylists(req, res).getPlaylists(0, 20, [], (playlists) ->
    return res.status(200).send(playlists)
  )
)

findVideos = (req, importStartTime, tracks) ->
  new Promise((resolve, reject) ->
    videos = {
      found: {}
      not_found: {}
    }
    k = 0
    async.eachSeries(Object.keys(tracks), (track_id, cb) ->
      track = tracks[track_id].track.name
      artist = ""
      if tracks[track_id].track.artists[0]
        artist = " "+tracks[track_id].track.artists[0].name
      console.log "Finding video for: "+track+"("+track_id+")"
      request({url: "https://www.googleapis.com/youtube/v3/search?q="+track+artist+"&maxResults=1&key=AIzaSyAyoWcB_yzEqESeJm-W_eC5QDcOu5R1M90&part=snippet", json: true}, (err, httpResponse, body) ->
        if err
          console.log "Youtube Error: "+err
          videos["not_found"][track_id] = track
          cb()
        else
          if body
            if body.items
              if body.items[0]
                request({url: "https://www.googleapis.com/youtube/v3/videos?id="+body.items[0].id.videoId+"&key=AIzaSyAyoWcB_yzEqESeJm-W_eC5QDcOu5R1M90&part=snippet,contentDetails", json: true}, (err, httpResponse, detailedBody) ->
                  if err
                    console.log "Youtube Error: "+err
                    videos["not_found"][track_id] = track
                    cb()
                  if detailedBody.items
                    if detailedBody.items[0]
                      video_obj = {
                        video_id: body.items[0].id.videoId,
                        video_title: body.items[0].snippet.title,
                        video_duration: convertTimestampToSeconds(detailedBody.items[0].contentDetails.duration)
                        track_details: tracks[track_id]
                      }
                      req.app.locals.motorbot.websocket.broadcast(JSON.stringify({type: 'SPOTIFY_IMPORT', op: 9, d: {event_type: "UPDATE", event_data: {user: req.user_id, start: importStartTime, message: "Finding "+track, progress: (25*(k/Object.keys(tracks).length)+25)/100}}}), req.user_id)
                      videos["found"][track_id] = video_obj
                      cb()
                    else
                      videos["not_found"][track_id] = track
                      cb()
                  else
                    videos["not_found"][track_id] = track
                    cb()
                  k++
                )
              else
                videos["not_found"][track_id] = track
                cb()
            else
              videos["not_found"][track_id] = track
              cb()
          else
            videos["not_found"][track_id] = track
            cb()
      )
    , (err) ->
      if err then console.log err
      console.log "Video Find Completed"
      resolve(videos)
    )
  )

importSongs = (req, videos, importStartTime) ->
#insert song from source
  songs = []
  tracksCollection = req.app.locals.motorbot.database.collection("tracks")
  k = 0
  new Promise((resolve, reject) ->
    async.eachSeries(videos, (track, cb) ->
      console.log track
      v = track
      track_id = uid()
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
        user_id: req.user_id,
      }
      tracksCollection.insertOne(track_obj, (err, result) ->
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
        req.app.locals.motorbot.websocket.broadcast(JSON.stringify({type: 'SPOTIFY_IMPORT', op: 9, d: {event_type: "UPDATE", event_data: {user: req.user_id, start: importStartTime, message: "Importing "+(v.track_details.track.name || v.video_title), progress: (25*(k/Object.keys(videos).length)+50)/100}}}), req.user_id)
        k++
      )
    , (err) ->
      if err then console.log err
      resolve(songs)
    )
  )

convertTimestampToSeconds = (input) ->
  reptms = /^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$/
  hours = 0
  minutes = 0
  seconds = 0

  if reptms.test(input)
    matches = reptms.exec(input)
    if (matches[1]) then hours = Number(matches[1])
    if (matches[2]) then minutes = Number(matches[2])
    if (matches[3]) then seconds = Number(matches[3])

  return hours*60*60+minutes*60+seconds;

getPlaylistTracks = (req, cb, tracks = {}, next = undefined, playlist_obj = undefined) ->
  if next
    url = next
  else
    url = "https://api.spotify.com/v1/users/"+req.params.spotify_owner_id+"/playlists/"+req.params.spotify_playlist_id
  request({
      url: url,
      json: true,
      'auth': {
        'bearer': req.user.connections["spotify"].access_token
      }
    }, (err, httpResponse, data) ->
    console.log "Got Tracks for playlist:"+req.params.spotify_playlist_id
    if err then return res.status(500).send({code: 500, status: "Internal Server Error", error: err})
    if data.tracks
      if data.tracks.items
        console.log "Parsing Tracks"
        for track in data.tracks.items
          console.log track.track.id+": "+track.track.name
          tracks[track.track.id || uid()] = track
        if data.tracks.offset == 0 && !playlist_obj
          playlist_id = uid()
          artwork = ""
          if data.images[0]
            artwork = data.images[0].url
          playlist_obj = {
            id: playlist_id
            type: "spotify playlist"
            name: data.name
            description: data.description || ""
            songs: []
            creator: req.user_id
            create_date: new Date().getTime()
            followers: [req.user_id]
            artwork: artwork
            private: !data.public || false
            collaborative: data.collaborative || false
          }
        if data.tracks.next
          getPlaylistTracks(req, cb, tracks, data.tracks.next, playlist_obj)
        else
          cb({tracks: tracks, playlist_obj: playlist_obj})
      else
        console.log "Playlist does not contain any tracks"
        console.log data
        cb({tracks: tracks, playlist_obj: playlist_obj})
    else if data.items
      console.log "Parsing Tracks:Offset:"+data.offset
      for track in data.items
        console.log track.track.id+": "+track.track.name
        tracks[track.track.id || uid()] = track
      if data.next
        getPlaylistTracks(req, cb, tracks, data.next, playlist_obj)
      else
        cb({tracks: tracks, playlist_obj: playlist_obj})
    else
      console.log "No Playlist Found"
      console.log data
      cb({tracks: tracks, playlist_obj: playlist_obj})
  )

router.get("/revoke", new OAuth(), (req, res) ->
  if req.user
    u = APIObjects.user(req)
    u.userById(req.user_id).then((user) ->
      u.revokeSpotify().then(() ->
        res.sendStatus(204)
      ).catch((err) ->
        res.type('json')
        res.status(500).send(JSON.stringify(err, Object.getOwnPropertyNames(err)))
      )
    )
  else
    res.sendStatus(403)
)

router.patch("/sync", new OAuth(), (req, res) ->
  sync = "true"
  if req.query.sync
    if req.query.sync == "true"
      sync = "true"
    else if req.query.sync == "false"
      sync = "false"
  console.log sync
  usersCollection = req.app.locals.motorbot.database.collection("users")
  usersCollection.find({id: req.user_id}).toArray((err, result) ->
    if err then console.log err
    if result[0]
      usersCollection.update({id: req.user_id},{$set: {"connections.spotify.sync": sync}}, (err, result) ->
        if err then console.log err
        if req.user
          if req.user.connections
            if req.user.connections["spotify"]
              req.user.connections["spotify"].sync = sync
        res.status(204).send()
      )
    else
      console.log "User doesn't exist"
      res.send(JSON.stringify({error: 404, message: "User Doesn't Exist"}))
  )
)

router.put("/playlist/:spotify_playlist_id/owner/:spotify_owner_id", new OAuth(), (req, res) ->
  req.setTimeout(0)
  importStartTime = new Date().getTime()
  APIWebSocket_Connection = new APIWebsocket(req)
  if req.user_id && req.params.spotify_playlist_id && req.params.spotify_owner_id
    if APIUtilities.has(req, "user.connections.spotify")
      APIWebSocket_Connection.send("SPOTIFY_IMPORT",{
        type: "START",
        importStartTime: importStartTime,
        message: "Gathering Data",
        progress: 0
      })
      APIObjects.spotifyPlaylists(req, res).getPlaylistTracks(req.params.spotify_owner_id,req.params.spotify_playlist_id).then((spotifyPlaylistResults) ->
        playlist = spotifyPlaylistResults.playlist
        tracks = spotifyPlaylistResults.tracks
        APIWebSocket_Connection.send("SPOTIFY_IMPORT",{
          type: "START",
          importStartTime: importStartTime,
          message: "Finding Songs",
          progress: 0.15
        })
        APIObjects.youtube(req).findVideosForSongsByName(tracks, importStartTime).then((videos) ->
          APIObjects.track(req).importTracksFromYoutubeForPlaylist(videos, importStartTime).then((short_songs) ->
            playlist.songs = short_songs
            APIWebSocket_Connection.send("SPOTIFY_IMPORT", {
              type: "UPDATE",
              start: importStartTime,
              message: "Finalising",
              progress: 0.9
            })
            APIObjects.playlist(req).importPlaylist(playlist).then(() ->
              APIObjects.user(req).addPlaylist(playlist.id).then(() ->
                res.type('json')
                res.send({"playlist":playlist,"not_found":videos["not_found"]})
                APIWebSocket_Connection.send("SPOTIFY_IMPORT", {
                  type: "END",
                  start: importStartTime,
                  message: "Done",
                  progress: 1
                })
              ).catch((err) ->
                res.type('json')
                res.status(500).send(JSON.stringify(err, Object.getOwnPropertyNames(err)))
              )
            ).catch((err) ->
              res.type('json')
              res.status(500).send(JSON.stringify(err, Object.getOwnPropertyNames(err)))
            )
          ).catch((err) ->
            res.type('json')
            res.status(500).send(JSON.stringify(err, Object.getOwnPropertyNames(err)))
          )
        ).catch((err) ->
          res.type('json')
          res.status(500).send(JSON.stringify(err, Object.getOwnPropertyNames(err)))
        )
      ).catch((err) ->
        res.type('json')
        res.status(500).send(JSON.stringify(err, Object.getOwnPropertyNames(err)))
      )
    else
      return res.status(429).send({code: 429, status: "Unauthorized"})
  else
    return res.status(400).send({code: 400, status: "Bad Request"})
)

module.exports = router