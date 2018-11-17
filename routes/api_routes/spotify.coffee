express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
request = require('request')
async = require('async')
uid = require('rand-token').uid;
passport = require 'passport'
moment = require 'moment'
SpotifyStrategy = require('passport-spotify').Strategy

###
  SPOTIFY ENDPOINT

  https://motorbot.io/api/spotify/

  Contains Endpoints:
  - GET /

  Authentication Required: false
  API Key Required: false
###

passport.serializeUser((user, done) ->
  done(null, user.id)
)

passport.deserializeUser((req, id, done) ->
  usersCollection = req.app.locals.motorbot.database.collection("users")
  usersCollection.find({id: id}).toArray((err, results) ->
    if results[0]
      done(null, results[0])
  )
)

passport.use(new SpotifyStrategy({
    clientID: "935356234ee749df96a3ab1999e0d659",
    clientSecret: "622b1a10ae054059bd2e5c260d87dabd",
    callbackURL: "https://motorbot.io/api/spotify/callback",
    passReqToCallback: true
  },
  (req, accessToken, refreshToken, profile, done) ->
    usersCollection = req.app.locals.motorbot.database.collection("users")
    usersCollection.find({id: req.user.id}).toArray((err, result) ->
      if err then done(err, undefined)
      if result[0]
        connections = {}
        if result[0].connections then connections = result[0].connections
        connections["spotify"] = {
          username: profile.username
          access_token: accessToken
          refresh_token: refreshToken
          expires: new Date().getTime() + 3600
          sync: true
        }
        usersCollection.update({id: req.user.id},{$set: {connections: connections}}, (err, result) ->
          if err
            done(err, undefined)
          else
            done(err, profile)
        )
      else
        done(err, undefined)
    )
  )
)

router.get("/", passport.authenticate('spotify', {scope: ['playlist-read-private', 'playlist-read-collaborative', 'user-read-recently-played', 'user-read-private user-top-read'], session: false}), (req, res) ->
  res.type('json')
)

router.get("/callback", passport.authenticate('spotify', { failureRedirect: 'https://motorbot.io/dashboard/account/connections', session: false }), (req, res) ->
  res.redirect("https://motorbot.io/dashboard/account/connections")
)

authChecker = (req, res, next) ->
  if !req.query.api_key
    return res.status(429).send({code: 429, status: "No API Key Supplied"})
  else
    APIAccessCollection = req.app.locals.motorbot.database.collection("apiaccess")
    APIAccessCollection.find({key: req.query.api_key}).toArray((err, results) ->
      if err then console.log err
      if results[0]
        client_id = results[0].id
        if req.headers["authorization"]
          bearerHeader = req.headers["authorization"]
          if typeof bearerHeader != 'undefined'
            bearer = bearerHeader.split(" ")
            bearerToken = bearer[1]
            console.log bearerToken
            accessTokenCollection = req.app.locals.motorbot.database.collection("accessTokens")
            accessTokenCollection.find({value: bearerToken}).toArray((err, result) ->
              if err then console.log err
              if result[0]
                if client_id == result[0].clientId
                  req.user_id = result[0].userId
                  req.client_id = result[0].clientId
                  return next()
                else
                  return res.status(429).send({code: 429, status: "Client Unauthorized"})
              else
                return res.status(429).send({code: 429, status: "Unknown Access Token"})
            )
          else
            return res.status(429).send({code: 429, status: "No Token Supplied"})
        else
          return res.status(429).send({code: 429, status: "No Token Supplied"})
      else
        return res.status(429).send({code: 429, status: "Unauthorized"})
    )

refreshAccessToken = (req, res, next) ->
  if req.user.connections
    if req.user.connections["spotify"]
      if req.user.connections["spotify"].refresh_token
        request({
          method: "POST",
          url: "https://accounts.spotify.com/api/token",
          json: true
          form: {
            "grant_type": "refresh_token",
            "refresh_token": req.user.connections["spotify"].refresh_token
          },
          headers: {
            "Content-Type": "application/x-www-form-urlencoded"
            "Authorization": "Basic "+new Buffer("935356234ee749df96a3ab1999e0d659:622b1a10ae054059bd2e5c260d87dabd").toString('base64')
          }
        }, (err, httpResponse, body) ->
          console.log err
          console.log body
          if body.access_token
            usersCollection = req.app.locals.motorbot.database.collection("users")
            usersCollection.find({id: req.user.id}).toArray((err, result) ->
              if err then console.log err
              if result[0]
                usersCollection.update({id: req.user.id},{$set: {"connections.spotify.access_token": body.access_token}}, (err, result) ->
                  if err then console.log err
                  if req.user
                    if req.user.connections
                      if req.user.connections["spotify"]
                        req.user.connections["spotify"].access_token = body.access_token
                  next()
                )
              else
                console.log "User doesn't exist"
                next()
            )
          else
            console.log "No Access Token was returned"
            next()
        )
      else
        next()
    else
      next()
  else
    next()

getSpotifyPlaylists = (req, res, offset, limit, playlists, cb) ->
  request({
      url: "https://api.spotify.com/v1/me/playlists?offset="+offset+"&limit="+limit,
      json: true,
      'auth': {
        'bearer': req.user.connections["spotify"].access_token
      }
    }, (err, httpResponse, data) ->
      if err then return res.status(500).send({code: 500, status: "Internal Server Error", error: err})
      if data.items
        playlists = playlists.concat(data.items);
      if data.next
        getSpotifyPlaylists(req, res, offset+limit, limit, playlists, cb)
      else
        if typeof cb == "function"
          cb(playlists)
  )


router.get("/playlists", refreshAccessToken, (req, res) ->
  res.type("json")
  if req.user
    if req.user.connections
      if req.user.connections["spotify"]
        getSpotifyPlaylists(req, res, 0, 20, [], (playlists) ->
          return res.status(200).send(playlists)
        )
      else
        return res.status(403).send({code: 403, status: "Unauthorized"})
    else
      return res.status(403).send({code: 403, status: "Unauthorized"})
  else
    return res.status(403).send({code: 403, status: "Unauthorized"})
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
      track_id = uid(32)
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
          tracks[track.track.id || uid(32)] = track
        if data.tracks.offset == 0 && !playlist_obj
          playlist_id = uid(32)
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
        tracks[track.track.id || uid(32)] = track
      if data.next
        getPlaylistTracks(req, cb, tracks, data.next, playlist_obj)
      else
        cb({tracks: tracks, playlist_obj: playlist_obj})
    else
      console.log "No Playlist Found"
      console.log data
      cb({tracks: tracks, playlist_obj: playlist_obj})
  )

router.get("/revoke", authChecker, (req, res) ->
  console.log(req.user_id);
  usersCollection = req.app.locals.motorbot.database.collection("users")
  usersCollection.find({id: req.user_id}).toArray((err, result) ->
    if err then console.log err
    if result[0]
      console.log "Found User"
      usersCollection.updateOne({id: req.user_id},{$unset: {"connections.spotify": ""}}, (err, result) ->
        if err then console.log err
        console.log "Updated User"
        if req.user
          if req.user.connections
            if req.user.connections["spotify"]
              req.user.connections = {}
              delete req.user.connections["spotify"]
        res.status(204).send()
      )
    else
      console.log "User doesn't exist"
      res.send(JSON.stringify({error: 404, message: "User Doesn't Exist"}))
  )
)

router.patch("/sync", authChecker, (req, res) ->
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

router.put("/playlist/:spotify_playlist_id/owner/:spotify_owner_id", authChecker, (req, res) ->
  req.setTimeout(0)
  importStartTime = new Date().getTime()
  if req.user_id && req.params.spotify_playlist_id && req.params.spotify_owner_id
    if req.user
      req.app.locals.motorbot.websocket.broadcast(JSON.stringify({type: 'SPOTIFY_IMPORT', op: 9, d: {event_type: "START", event_data: {user: req.user_id, start: importStartTime, message: "Gathering Data", progress: (0/100)}}}), req.user_id)
      if req.user.connections
        if req.user.connections["spotify"]
          getPlaylistTracks(req, (tracks) ->
            playlist_obj = tracks.playlist_obj
            playlist_id = playlist_obj.id
            tracks = tracks.tracks
            req.app.locals.motorbot.websocket.broadcast(JSON.stringify({type: 'SPOTIFY_IMPORT', op: 9, d: {event_type: "START", event_data: {user: req.user_id, start: importStartTime, message: "Finding Songs", progress: (25/100)}}}), req.user_id)
            console.log "Finding Youtube Videos"
            findVideos(req, importStartTime, tracks).then((videos) ->
              console.log "Video Find Complete"
              console.log videos
              if Object.keys(videos).length >= 0
                video_id_list = []
                for spotify_id, video of videos["found"]
                  video_id_list.push(video.video_id)
                console.log video_id_list
                tracksCollection = req.app.locals.motorbot.database.collection("tracks")
                tracksCollection.find({video_id:{"$in":video_id_list}}).toArray((err, results) ->
                  if err then return res.status(500).send({code: 500, status: "Internal Server Error", error: err})
                  if results[0]
                    console.log "Determined Repeats"
                    for song in results
                      if song.artwork && !playlist_obj.artwork
                        playlist_obj.artwork = song.artwork
                      date_added = new Date().getTime()
                      for spotify_id, video of videos["found"]
                        if video.video_id == song.video_id
                          console.log video.track_details.added_at
                          date_added = moment(video.track_details.added_at).unix()*1000
                          delete videos["found"][spotify_id]
                      playlist_obj.songs.push({
                        id: song.id
                        date_added: date_added
                        play_count: 0
                        last_played: undefined
                      })
                  console.log "Import Other Songs"
                  importSongs(req, videos["found"], importStartTime).then((small_song_obj)->
                    for song in small_song_obj
                      playlist_obj.songs.push(song)
                    req.app.locals.motorbot.websocket.broadcast(JSON.stringify({type: 'SPOTIFY_IMPORT', op: 9, d: {event_type: "UPDATE", event_data: {user: req.user_id, start: importStartTime, message: "Finalising", progress: (75/100)}}}), req.user_id)
                    console.log "Inserting Playlist"
                    playlistsCollection = req.app.locals.motorbot.database.collection("playlists")
                    playlistsCollection.insertOne(playlist_obj, (err, result) ->
                      if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
                      console.log "User receiving access to playlist"
                      usersCollection = req.app.locals.motorbot.database.collection("users")
                      usersCollection.find({id: req.user_id}).toArray((err, results) ->
                        if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
                        if results[0]
                          playlists = results[0].playlists
                          playlists.push(playlist_id)
                          usersCollection.update({id: req.user_id},{$set: {playlists: playlists}}, (err, result) ->
                            if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
                            res.send({"playlist":playlist_obj,"not_found":videos["not_found"]})
                            req.app.locals.motorbot.websocket.broadcast(JSON.stringify({type: 'SPOTIFY_IMPORT', op: 9, d: {event_type: "END", event_data: {user: req.user_id, start: importStartTime, message: "Done", progress: (100/100), report: {"playlist":playlist_obj,"not_found":videos["not_found"]}}}}), req.user_id)
                          )
                        else
                          return res.status(404).send({code: 404, status: "User Not Found"})
                      )
                    )
                  ).catch((err) ->
                    console.log "Importing Failed"
                    console.log err
                  )
                  )
              else
                return res.status(404).send({code: 404, status: "No Videos Found"})
            )
          )
        else
          return res.status(429).send({code: 429, status: "Unauthorized"})
      else
        return res.status(429).send({code: 429, status: "Unauthorized"})
    else
      return res.status(429).send({code: 429, status: "Unauthorized"})
  else
    return res.status(400).send({code: 400, status: "Bad Request"})
)

module.exports = router