express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
globals = require '../../models/globals.coffee'
request = require('request')
async = require('async')
uid = require('rand-token').uid;
passport = require 'passport'
SpotifyStrategy = require('passport-spotify').Strategy

###
  SPOTIFY ENDPOINT

  https://mb.lolstat.net/api/spotify/

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
    callbackURL: "https://mb.lolstat.net/api/spotify/callback",
    passReqToCallback: true
  },
  (req, accessToken, refreshToken, profile, done) ->
    usersCollection = req.app.locals.motorbot.database.collection("users")
    usersCollection.find({id: req.user.id}).toArray((err, result) ->
      if err then done(err, undefined)
      if result[0]
        connections = {}
        if result[0].connections then connections = result[0].connections
        profile.access_token = accessToken
        profile.refresh_token = refreshToken
        connections["spotify"] = profile
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

router.get("/", passport.authenticate('spotify', {scope: ['playlist-read-collaborative', 'playlist-read-private'], session: false}), (req, res) ->
  res.type('json')
)

router.get("/callback", passport.authenticate('spotify', { failureRedirect: 'https://mb.lolstat.net/dashboard/connections/', session: false }), (req, res) ->
  res.redirect("https://mb.lolstat.net/dashboard/connections/")
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
                usersCollection.update({id: req.user.id},{$set: {"connections.spotify.access_token": body.access_token, "connections.spotify.refresh_token": body.refresh_token}}, (err, result) ->
                  if err then console.log err
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


router.get("/playlists", refreshAccessToken, (req, res) ->
  res.type("json")
  if req.user
    if req.user.connections
      if req.user.connections["spotify"]
        request({
          url: "https://api.spotify.com/v1/me/playlists",
          json: true,
          'auth': {
            'bearer': req.user.connections["spotify"].access_token
          }
        }, (err, httpResponse, data) ->
          if err then return res.status(500).send({code: 500, status: "Internal Server Error", error: err})
          if data.items
            return res.status(200).send(data.items)
          else
            return res.status(404).send({code: 404, status: "No Playlists Found", response: data})
        )
      else
        return res.status(429).send({code: 429, status: "Unauthorized"})
    else
      return res.status(429).send({code: 429, status: "Unauthorized"})
  else
    return res.status(429).send({code: 429, status: "Unauthorized"})
)

findVideos = (tracks) ->
  new Promise((resolve, reject) ->
    videos = {
      found: {}
      not_found: {}
    }
    async.eachSeries(Object.keys(tracks), (track_id, cb) ->
      track = tracks[track_id]
      console.log "Finding video for: "+track+"("+track_id+")"
      request({url: "https://www.googleapis.com/youtube/v3/search?q="+track+"&part=snippet&maxResults=1&key=AIzaSyAyoWcB_yzEqESeJm-W_eC5QDcOu5R1M90", json: true}, (err, httpResponse, body) ->
        if err
          console.log "Youtube Error: "+err
          videos["not_found"][track_id] = track
          cb()
        if body.items
          if body.items[0]
            video_obj = {
              video_id: body.items[0].id.videoId,
              video_title: body.items[0].snippet.title
            }
            videos["found"][track_id] = video_obj
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

importSongs = (req, videos) ->
#insert song from source
  songs = []
  tracksCollection = req.app.locals.motorbot.database.collection("tracks")
  new Promise((resolve, reject) ->
    async.eachSeries(videos, (video_id, cb) ->
      request.get({
        url: "https://www.googleapis.com/youtube/v3/videos?id="+video_id+"&key=AIzaSyAyoWcB_yzEqESeJm-W_eC5QDcOu5R1M90&part=snippet,contentDetails",
        json: true
      }, (err, httpResponse, data) ->
        if err
          console.log err
          setTimeout(cb,500)
        if data.items[0]
          modifiedTitle = data.items[0].snippet.title.replace(/\[((?!.*?Remix))[^\)]*\]/gmi, '').replace(/\(((?!.*?Remix))[^\)]*\)/gmi, '').replace(/\-(\s|)[0-9]*(\s|)\-/g, '').replace(/(\s|)-(\s|)/gmi," ").replace(/\sFrom\s(.*)\/(|\s)Soundtrack/gmi, "").replace(/(high\squality|\sOST|playlist|\sHD|\sHQ|\s1080p|ft\.|feat\.|ft\s|lyrics|official\svideo|\"|official|video|:|\/Soundtrack\sVersion|\/Soundtrack|\||w\/|\/)/gmi, '')
          modifiedTitle = encodeURIComponent(modifiedTitle)
          console.log modifiedTitle
          request.get({url: "https://api.spotify.com/v1/search?type=track&q="+modifiedTitle+"+NOT+Karaoke", json: true}, (err, httpResponse, body) ->
            if err
              console.log err
              setTimeout(cb,500)
            else
              artist = {}
              album = {}
              composer = {}
              album_artist = {}
              title = decodeURIComponent(modifiedTitle)
              genres = []
              release_date = undefined
              track_number = 0
              disc_number = 0
              artwork = ""
              explicit = false
              if body.tracks
                if body.tracks.items[0]
                  if body.tracks.items[0].artists[0]
                    id = new Buffer(body.tracks.items[0].artists[0].name, 'base64')
                    artist = {
                      name: body.tracks.items[0].artists[0].name,
                      id: id.toString('hex')
                    }
                  if body.tracks.items[0].album
                    id = new Buffer(body.tracks.items[0].album.name, 'base64')
                    album_artwork = ""
                    if body.tracks.items[0].album.images[0] then album_artwork = body.tracks.items[0].album.images[0].url
                    artwork = album_artwork
                    album = {
                      name: body.tracks.items[0].album.name,
                      artwork: album_artwork
                      id: id.toString('hex')
                    }
                    if body.tracks.items[0].album.artists[0]
                      id = new Buffer(body.tracks.items[0].album.artists[0].name, 'base64')
                      album_artist = {
                        name: body.tracks.items[0].album.artists[0].name,
                        id: id.toString('hex')
                      }
                  title = body.tracks.items[0].name.replace(/\[((?!.*?Remix))[^\)]*\]/gmi, '').replace(/\(((?!.*?Remix))[^\)]*\)/gmi, '').replace(/\-(\s|)[0-9]*(\s|)\-/g, '').replace(/(\s|)-(\s|)/gmi," ").replace(/\sFrom\s(.*)\/(|\s)Soundtrack/gmi, "").replace(/(high\squality|\sOST|playlist|\sHD|\sHQ|\s1080p|ft\.|feat\.|ft\s|lyrics|official\svideo|\"|official|video|:|\/Soundtrack\sVersion|\/Soundtrack|\||w\/|\/)/gmi, '')
                  track_number = Number(body.tracks.items[0].track_number)
                  disc_number = Number(body.tracks.items[0].disc_number)
                  explicit = body.tracks.items[0].explicit
              track_id = uid(32)
              track_obj = {
                id: track_id,
                type: "youtube",
                video_id: video_id,
                video_title: data.items[0].snippet.title,
                title: title,
                artist: artist,
                album: album,
                composer: composer,
                album_artist: album_artist
                genres: genres,
                duration: convertTimestampToSeconds(data.items[0].contentDetails.duration),
                import_date: new Date().getTime(),
                release_date: release_date,
                track_number: track_number,
                disc_number: disc_number,
                play_count: 0,
                artwork: artwork,
                explicit: explicit
                lyrics: "",
                user_id: req.user_id,
              }
              tracksCollection.insertOne(track_obj, (err, result) ->
                if err
                  console.log err
                  setTimeout(cb,500)
                else
                  song_obj = {
                    id: track_obj.id
                    date_added: new Date().getTime()
                    play_count: 0
                    last_played: undefined
                  }
                  songs.push(song_obj)
                  setTimeout(cb,500)
              )
          )
        else
          console.log "Song Not Found"
          console.log data
          setTimeout(cb,500)
      )
    , (err) ->
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
          if track.track.id
            tracks[track.track.id] = track.track.name+" "+track.track.artists[0].name
          else
            tracks[uid(32)] = track.track.name
        if data.tracks.offset == 0 && !playlist_obj
          playlist_id = uid(32)
          playlist_obj = {
            id: playlist_id
            name: data.name
            description: data.description
            songs: []
            creator: req.user_id
            create_date: new Date().getTime()
            followers: [req.user_id]
            artwork: ""
            private: !data.public
            collaborative: false
          }
        if data.tracks.next
          getPlaylistTracks(req, cb, tracks, data.tracks.next, playlist_obj)
        else
          cb({tracks: tracks, playlist_obj: playlist_obj})
      else
        console.log "65356. No Playlist Found"
        console.log data
        cb({tracks: tracks, playlist_obj: playlist_obj})
    else if data.items
      console.log "Parsing Tracks:Offset:"+data.offset
      for track in data.items
        console.log track.track.id+": "+track.track.name
        if track.track.id
          tracks[track.track.id] = track.track.name+" "+track.track.artists[0].name
        else
          tracks[uid(32)] = track.track.name
      if data.next
        getPlaylistTracks(req, cb, tracks, data.next, playlist_obj)
      else
        cb({tracks: tracks, playlist_obj: playlist_obj})
    else
      console.log "34563. No Playlist Found"
      console.log data
      cb({tracks: tracks, playlist_obj: playlist_obj})
  )

router.put("/playlist/:spotify_playlist_id/owner/:spotify_owner_id", authChecker, (req, res) ->
  req.setTimeout(0)
  if req.user_id && req.params.spotify_playlist_id && req.params.spotify_owner_id
    if req.user
      if req.user.connections
        if req.user.connections["spotify"]
          getPlaylistTracks(req, (tracks) ->
            playlist_obj = tracks.playlist_obj
            playlist_id = playlist_obj.id
            tracks = tracks.tracks
            console.log "Finding Youtube Videos"
            findVideos(tracks).then((videos) ->
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
                      index = video_id_list.indexOf(song.video_id);
                      video_id_list.splice(index, 1);
                      if song.artwork && !playlist_obj.artwork
                        playlist_obj.artwork = song.artwork
                      playlist_obj.songs.push({
                        id: song.id
                        date_added: new Date().getTime()
                        play_count: 0
                        last_played: undefined
                      })
                  console.log "Import Other Songs"
                  importSongs(req, video_id_list).then((small_song_obj)->
                    for song in small_song_obj
                      playlist_obj.songs.push(song)
                    console.log "Inserting Playlist"
                    playlistsCollection = req.app.locals.motorbot.database.collection("playlists")
                    playlistsCollection.insertOne(playlist_obj, (err, result) ->
                      if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
                      console.log "User recieving access to playlist"
                      usersCollection = req.app.locals.motorbot.database.collection("users")
                      usersCollection.find({id: req.user_id}).toArray((err, results) ->
                        if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
                        if results[0]
                          playlists = results[0].playlists
                          playlists.push(playlist_id)
                          usersCollection.update({id: req.user_id},{$set: {playlists: playlists}}, (err, result) ->
                            if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
                            res.send({"playlist":playlist_obj,"not_found":videos["not_found"]})
                          )
                        else
                          return res.status(404).send({code: 404, status: "User Not Found"})
                      )
                    )
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