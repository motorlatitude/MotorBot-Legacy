express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
globals = require '../../models/globals.coffee'
request = require('request')
async = require('async')
request = require 'request'
uid = require('rand-token').uid;
async = require 'async'
multer = require 'multer'
path = require 'path'

storage = multer.diskStorage({
  destination: (req, file, callback) ->
    callback(null, path.join(__dirname, '../../static/AlbumArt'))
  ,filename: (req, file, callback) ->
    req.app.locals.albumartkey = uid(20)+"."+file.originalname.split('.')[1]
    callback(null, req.app.locals.albumartkey)
})
upload = multer({ storage : storage}).single('artworkFile');

###
  PLAYLIST ENDPOINT

  https://mb.lolstat.net/api/playlist/

  Contains Endpoints:
  - POST: /                                   - create new playlist
  - DELETE: /{playlist_id}                    - delete playlist
  - PUT: /{playlist_id}/song                  - add new song from source
  - GET: /{playlist_id}                       - get playlist
  - PATCH: /{playlist_id}/song/{song_id}      - add song from song DB
  - DELETE: /{playlist_id}/song/{song_id}     - delete song from playlist

  Authentication Required: true
  API Key Required: true
###

#API Key & OAuth Checker
router.use((req, res, next) ->
  if !req.query.api_key
    return res.status(401).send({code: 401, status: "No API Key Supplied"})
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
                  return res.status(401).send({code: 401, status: "Client Unauthorized"})
              else
                return res.status(401).send({code: 401, status: "Unknown Access Token"})
            )
          else
            return res.status(401).send({code: 401, status: "No Token Supplied"})
        else
          return res.status(401).send({code: 401, status: "No Token Supplied"})
      else
        return res.status(401).send({code: 401, status: "Unauthorized"})
    )
)

insertSongIntoQueue = (req, res, insertionObj, playlist_id) ->
  songsQueueCollection = req.app.locals.motorbot.database.collection("songQueue")
  songsQueueCollection.find({status: {$in: ["added","playing"]}}).toArray((err, results) ->
    if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
    if results[0]
      addToQueue = false
      for song in results
        console.log song
        if song.playlistId == playlist_id
          addToQueue = true
          break;
      if addToQueue
        insertionObj.status = "added"
        insertionObj.songId = insertionObj.id.toString()
        insertionObj._id = undefined
        insertionObj.playlistId = playlist_id
        songsQueueCollection.insert(insertionObj, (err, result) ->
          if err then console.log err
          console.log "Added to Song Queue"
          req.app.locals.motorbot.websocket.broadcast(JSON.stringify(insertionObj))
          res.send({added: true})
        )
      else
        console.log "Songs in queue don't match altered playlist"
        req.app.locals.motorbot.websocket.broadcast(JSON.stringify(insertionObj))
        res.send({added: true})
    else
      console.log "Queue Empty"
      req.app.locals.motorbot.websocket.broadcast(JSON.stringify(insertionObj))
      res.send({added: true})
  )

refreshSpotifyAccessToken = (req, res, next) ->
  usersCollection = req.app.locals.motorbot.database.collection("users")
  #this will retrieve my local spotify connection authorization token and get a new token with each request
  usersCollection.find({id: "95164972807487488"}).toArray((err, result) ->
    if err then console.log err
    if result[0].connections
      if result[0].connections["spotify"]
        if result[0].connections["spotify"].refresh_token
          request({
            method: "POST",
            url: "https://accounts.spotify.com/api/token",
            json: true
            form: {
              "grant_type": "refresh_token",
              "refresh_token": result[0].connections["spotify"].refresh_token
            },
            headers: {
              "Content-Type": "application/x-www-form-urlencoded"
              "Authorization": "Basic "+new Buffer("935356234ee749df96a3ab1999e0d659:622b1a10ae054059bd2e5c260d87dabd").toString('base64')
            }
          }, (err, httpResponse, body) ->
            console.log err
            console.log body
            if body.access_token
              usersCollection.find({id: result[0].id}).toArray((err, result) ->
                if err then console.log err
                if result[0]
                  usersCollection.update({id: result[0].id},{$set: {"connections.spotify.access_token": body.access_token}}, (err, result) ->
                    if err then console.log err
                    res.locals.spotify_access_token = body.access_token
                    next()
                  )
                else
                  console.log "User doesn't exist"
                  res.locals.spotify_access_token = body.access_token
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
  )

router.post("/uploadArtwork", (req, res) ->
  upload(req,res,(err) ->
    if err
      console.log err
      console.log "Error Uploading File"
      return res.end("Error uploading file")
    else
      res.end("File is uploaded")
  )
)

router.post("/", (req, res) ->
  res.type("json")
  user_id = req.user_id
  playlistsCollection = req.app.locals.motorbot.database.collection("playlists")
  usersCollection = req.app.locals.motorbot.database.collection("users")
  playlist_id = uid(32);
  album_key = undefined
  if req.app.locals.albumartkey
    album_key = "https://mb.lolstat.net/AlbumArt/"+req.app.locals.albumartkey
  if req.body.playlist_name
    playlistObj = {
      id: playlist_id
      name: req.body.playlist_name
      description: req.body.playlist_description || ""
      songs: []
      creator: user_id
      create_date: new Date().getTime()
      followers: [user_id]
      artwork: album_key || ""
      private: req.body.private || false
      collaborative: req.body.collaborative || false
    }
    playlistsCollection.insertOne(playlistObj, (err, result) ->
      if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
      usersCollection.find({id: user_id}).toArray((err, results) ->
        if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
        if results[0]
          playlists = results[0].playlists
          playlists.push(playlist_id)
          usersCollection.update({id: user_id},{$set: {playlists: playlists}}, (err, result) ->
            if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
            res.send(playlistObj)
          )
      )
    )
  else
    api_response = {
      "Response": {},
      "ErrorCode": 3,
      "ErrorStatus": "Incorrectly Formatted Request",
      "Message": "No playlist name was supplied"
    }
    res.send(api_response)
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


router.get("/songTransferToTrack/:skip/:limit", (req, res) ->
  songsCollection = req.app.locals.motorbot.database.collection("songs")
  tracksCollection = req.app.locals.motorbot.database.collection("tracks")
  songsCollection.find({}).skip(parseInt(req.params.skip)).limit(parseInt(req.params.limit)).toArray((err, results) ->
    if err then console.log err
    if results
      i = 1
      async.eachSeries(results, (result, callback) ->
        console.log "Processing "+i+"/"+results.length
        modifiedTitle = result.title.replace(/\[((?!.*?Remix))[^\)]*\]/gmi, '').replace(/\(((?!.*?Remix))[^\)]*\)/gmi, '').replace(/\-(\s|)[0-9]*(\s|)\-/g, '').replace(/(\s|)-(\s|)/gmi," ").replace(/\sFrom\s(.*)\/(|\s)Soundtrack/gmi, "").replace(/(high\squality|\sOST|playlist|\sHD|\sHQ|\s1080p|ft\.|feat\.|ft\s|lyrics|official\svideo|\"|official|video|:|\/Soundtrack\sVersion|\/Soundtrack|\||w\/|\/)/gmi, '')
        #modifiedTitle = encodeURIComponent(modifiedTitle)
        console.log modifiedTitle
        request.get({
            url: "https://api.spotify.com/v1/search?type=track&q=" + modifiedTitle,
            json: true,
            headers: {
              "Authorization": "Bearer BQAgotImSiaQGP15ALbQdTobE9V7RHprS4mArIYDb6GerOozv7XMtoTCb4lCt5Xzvyzvfm18ZBCHBpxcNNEaUKstrQ4CMgReGxtsC7-V6na_jjWe6iaHE88UMjCdOC3ZOYSIRfD_hTU4doA"
            }
          }, (err, httpResponse, body) ->
          if err then return res.status(500).send({code: 500, status: "Spotify API Error", error: err})
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
                console.log "[->] Found on Spotify"
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
            track_obj = {
              id: result._id.toString()
              type: "youtube"
              video_id: result.videoId,
              video_title: result.title,
              title: title,
              artist: artist,
              album: album,
              composer: composer,
              album_artist: album_artist
              genres: genres,
              duration: convertTimestampToSeconds(result.duration),
              import_date: result.timestamp,
              release_date: release_date,
              track_number: track_number,
              disc_number: disc_number,
              play_count: 0,
              artwork: artwork,
              explicit: explicit
              lyrics: "",
              user_id: result.userId || "169554882674556930",
            }
            tracksCollection.insertOne(track_obj, (err, result) ->
              if err then console.log err
              console.log "Imported Track"
              callback()
            )
            i++
        )
      , (err) ->
        res.status(200).send({code: 200, status: "OKAY"})
      )
  )
)

router.get("/playlistTransfer", (req, res) ->
  playlistsCollection = req.app.locals.motorbot.database.collection("old_playlists")
  new_playlistsCollection = req.app.locals.motorbot.database.collection("playlists")
  usersCollection = req.app.locals.motorbot.database.collection("users")
  playlistsCollection.find({}).toArray((err, results) ->
    if err then console.log err
    if results[0]
      i = 1
      async.eachSeries(results, (result, cb) ->
        console.log "Transferring Playlist "+i+"/"+results.length
        i++
        songs = []
        followers = []
        k = new Date().getTime() - result.songs.length*1000
        n = 0
        for song in result.songs
          songs.push({
            id: song.toString()
            date_added: k + (n*1000)
            play_count: 0
            last_played: undefined
          })
          n++
        usersCollection.find({playlists:{$in:[result.id]}}).toArray((err, users) ->
          if err then cb(err)
          if users
            for user in users
              followers.push(user.id)
          playlist_obj = {
            id: result.id
            name: result.name
            description: ""
            songs: songs
            creator: result.creator
            create_date: result.timestamp
            followers: followers
            artwork: result.artwork
            private: false
            collaborative: false
          }
          new_playlistsCollection.insertOne(playlist_obj, (err, result) ->
            cb(err)
          )
        )
      , (err) ->
        if err then console.log err
        res.status(200).send({code: 200, status: "OKAY"})
      )
  )
)

router.put("/:playlist_id/song", refreshSpotifyAccessToken, (req, res) ->
  #from source so add to Songs DB
  res.type("json")
  if req.user_id
    console.log "PUT new song from source"
    console.log req.body
    #vars
    source = req.body.source
    video_id = req.body.video_id
    song_id = req.body.song_id
    playlist_id = req.params.playlist_id
    user_id = req.user_id
    #Collections
    tracksCollection = req.app.locals.motorbot.database.collection("tracks")
    playlistsCollection = req.app.locals.motorbot.database.collection("playlists")
    if source == "ytb"
      tracksCollection.find({video_id: video_id}).toArray((err, results) ->
        if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
        if results[0]
          #song already in tracksCollection
          insertionObj = results[0]
          insertionObj.type = "trackAdded"
          insertionObj.playlistId = playlist_id
          song_obj = {
            id: insertionObj.id
            date_added: new Date().getTime()
            play_count: 0
            last_played: undefined
          }
          playlistsCollection.find({"id":playlist_id, "creator": user_id}).toArray((err, results) ->
            if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
            if results[0]
              playlist = results[0]
              if playlist.artwork == "" && insertionObj.artwork != ""
                #update playlist artwork
                playlistsCollection.update({"id":playlist_id,"creator":user_id},{"$push": {songs: song_obj}, "$set": {artwork: insertionObj.artwork}}, (err, result) ->
                  if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
                  #insert into song queue if active queue
                  insertSongIntoQueue(req, res, insertionObj, playlist_id)
                )
              else
                playlistsCollection.update({"id":playlist_id,"creator":user_id},{"$push": {songs: song_obj}}, (err, result) ->
                  if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
                  #insert into song queue if active queue
                  insertSongIntoQueue(req, res, insertionObj, playlist_id)
                )
            else
              return res.status(404).send({code: 404, status: "Playlist Not Found"})
          )
        else
          #insert song from source
          console.log("Spotify Authorization Code: "+res.locals.spotify_access_token)
          request.get({
            url: "https://www.googleapis.com/youtube/v3/videos?id="+video_id+"&key=AIzaSyAyoWcB_yzEqESeJm-W_eC5QDcOu5R1M90&part=snippet,contentDetails",
            json: true
          }, (err, httpResponse, data) ->
            if err then return res.status(500).send({code: 500, status: "Youtube API Error", error: err})
            if data.items[0]
              modifiedTitle = data.items[0].snippet.title.replace(/\[((?!.*?Remix))[^\)]*\]/gmi, '').replace(/\(((?!.*?Remix))[^\)]*\)/gmi, '').replace(/\-(\s|)[0-9]*(\s|)\-/g, '').replace(/(\s|)-(\s|)/gmi," ").replace(/(\sI\s|\s:\s)/gmi, " ").replace(/\sFrom\s(.*)\/(|\s)Soundtrack/gmi, "").replace(/(high\squality|\sOST|playlist|\sHD|\sHQ|\s1080p|\s720p|ft\.|feat\.|ft\s|lyrics|official\svideo|\"|official|video|:|\/Soundtrack\sVersion|\/Soundtrack|\||w\/|\/)/gmi, '')
              modifiedTitle = encodeURIComponent(modifiedTitle.trim())
              console.log modifiedTitle
              request.get({
                url: "https://api.spotify.com/v1/search?type=track&q=" + modifiedTitle,
                json: true,
                headers: {
                  "Authorization": "Bearer "+res.locals.spotify_access_token
                }
              }, (err, httpResponse, body) ->
                if err then return res.status(500).send({code: 500, status: "Spotify API Error", error: err})
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
                    user_id: user_id,
                  }
                  tracksCollection.insertOne(track_obj, (err, result) ->
                    if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
                    else
                      insertionObj = track_obj
                      insertionObj.type = "trackAdded"
                      insertionObj.playlistId = playlist_id
                      song_obj = {
                        id: insertionObj.id
                        date_added: new Date().getTime()
                        play_count: 0
                        last_played: undefined
                      }
                      #add to playlist
                      playlistsCollection.find({"id":playlist_id,"creator":user_id}).toArray((err, results) ->
                        if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
                        if results[0]
                          playlist = results[0]
                          if playlist.artwork == "" && insertionObj.artwork != ""
                            #update playlist artwork
                            playlistsCollection.update({"id":playlist_id,"creator":user_id},{"$push": {songs: song_obj}, "$set": {artwork: insertionObj.artwork}}, (err, result) ->
                              if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
                              #insert into song queue if active queue
                              insertSongIntoQueue(req, res, insertionObj, playlist_id)
                            )
                          else
                            playlistsCollection.update({"id":playlist_id,"creator":user_id},{"$push": {songs: song_obj}}, (err, result) ->
                              if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
                              #insert into song queue if active queue
                              insertSongIntoQueue(req, res, insertionObj, playlist_id)
                            )
                        else
                          return res.status(404).send({code: 404, status: "Playlist Not Found"})
                      )
                  )
              )
            else
              return res.status(404).send({code: 404, status: "Youtube API Error", error: "Video Not Found"})
          )
      )
    else if source == "scd"
      tracksCollection.find({soundcloud_id: video_id}).toArray((err, results) ->
        if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
        if results[0]
          #song already in the database
          insertionObj = results[0]
          insertionObj.type = "trackAdded"
          insertionObj.playlistId = playlist_id
          song_obj = {
            id: insertionObj.id
            date_added: new Date().getTime()
            play_count: 0
            last_played: undefined
          }
          playlistsCollection.find({"id":playlist_id, "creator": user_id}).toArray((err, results) ->
            if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
            if results[0]
              playlist = results[0]
              if playlist.artwork == "" && insertionObj.artwork != ""
                #update playlist artwork
                playlistsCollection.update({"id":playlist_id,"creator":user_id},{"$push": {songs: song_obj}, "$set": {artwork: insertionObj.artwork}}, (err, result) ->
                  if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
                  #insert into song queue if active queue
                  insertSongIntoQueue(req, res, insertionObj, playlist_id)
                )
              else
                playlistsCollection.update({"id":playlist_id,"creator":user_id},{"$push": {songs: song_obj}}, (err, result) ->
                  if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
                  #insert into song queue if active queue
                  insertSongIntoQueue(req, res, insertionObj, playlist_id)
                )
            else
              return res.status(404).send({code: 404, status: "Playlist Not Found"})
          )
        else
          #insert song from source
      )
  else
    return res.status(429).send({code: 429, status: "Unauthorized"})
)

router.patch("/:playlist_id/song/:song_id", (req, res) ->
  #add song from another playlist or song DB transfer
  playlist_id = req.params.playlist_id
  song_id = req.params.song_id
  playlistCollection = req.app.locals.motorbot.database.collection("playlists")
  tracksCollection = req.app.locals.motorbot.database.collection("tracks")

  playlistCollection.find({id: playlist_id}).toArray((err, results) ->
    if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
    if results[0]
      playlist = results[0]
      tracksCollection.find({id: song_id}).toArray((err, results) ->
        if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
        if results[0]
          song_obj = {
            id: song_id
            date_added: new Date().getTime()
            play_count: 0
            last_played: undefined
          }
          if playlist.artwork == "" && results[0].artwork != ""
            playlistCollection.update({id: playlist_id},{$push: {songs: song_obj}, $set: {artwork: results[0].artwork}}, (err, result) ->
              if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
              return res.status(200).send({code: 200, status: "OKAY"})
            )
          else
            playlistCollection.update({id: playlist_id},{$push: {songs: song_obj}}, (err, result) ->
              if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
              return res.status(200).send({code: 200, status: "OKAY"})
            )
        else
          return res.status(404).send({code: 404, status: "Unknown Song"})
      )
    else
      return res.status(404).send({code: 404, status: "Unknown Playlist"})
  )
)

router.delete("/:playlist_id", (req, res) ->
  playlistsCollection = req.app.locals.motorbot.database.collection("playlists")
  usersCollection = req.app.locals.motorbot.database.collection("users")
  user_id = req.user_id
  playlist_id = req.params.playlist_id
  playlistsCollection.remove({"id": playlist_id, "creator": user_id}, (err, result) ->
    if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
    else
      console.log result.result.n
      if result.result.n == 1
        usersCollection.update({}, {"$pull":{"playlists": playlist_id}}, {multi: true}, (err, result) ->
          if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
          else
            res.send({"status": 200,"message":"OKAY"})
        )
      else
        return res.status(404).send({code: 404, status: "Playlist Not Found For User"})
  )
)

router.get("/:playlist_id", (req, res) ->
  if req.user_id
    playlistCollection = req.app.locals.motorbot.database.collection("playlists")
    playlistCollection.find({id: req.params.playlist_id}).toArray((err, results) ->
      if err then console.log err
      if results[0]
        playlist = results[0]
        usersCollection = req.app.locals.motorbot.database.collection("users")
        usersCollection.find({id: playlist.creator}).toArray((err, results) ->
          if results[0]
            playlist["creatorName"] = {username: results[0].username, discriminator: results[0].discriminator}
          if playlist.songs.length > 0
            songsList = []
            songs = {}
            for song in playlist.songs
              songsList.push(song.id)
              songs[song.id.toString()] = song
            tracksCollection = req.app.locals.motorbot.database.collection("tracks")
            tracksCollection.find({id: {$in: songsList}}).toArray((err, results) ->
              if err then console.log err
              finalSongs = []
              songList = {}
              if results[0]
                for song in results
                  songList[song.id.toString()] = song
                  songList[song.id.toString()].date_added = songs[song.id.toString()].date_added
                  songList[song.id.toString()].playlist_play_count = songs[song.id.toString()].play_count
                  songList[song.id.toString()].last_played = songs[song.id.toString()].last_played
                for song in songsList
                  finalSongs.push(songList[song.toString()])
                playlist.songs = finalSongs
                res.type('json')
                res.end(JSON.stringify(playlist))
              else
                res.sendStatus(404)
            )
          else
            res.type('json')
            res.end(JSON.stringify(playlist)) #only return the playlist object
        )
      else
        res.sendStatus(404)
    )
  else
    return res.status(429).send({code: 429, status: "Unauthorized"})
)

router.delete("/:playlist_id/song/:song_id", (req, res) ->
  playlistCollection = req.app.locals.motorbot.database.collection("playlists")
  tracksCollection = req.app.locals.motorbot.database.collection("tracks")
  songQueueCollection = req.app.locals.motorbot.database.collection("songQueue")
  playlist_id = req.params.playlist_id
  song_id = req.params.song_id
  user_id = req.user_id
  res.type("json")
  if user_id
    playlistCollection.find({id: playlist_id, creator: user_id}).toArray((err, results) ->
      if err then return res.status(500).send({code: 500, status: "Internal Server Error", reason: err})
      if results[0]
        playlist = results[0]
        tracksCollection.find({id: song_id}).toArray((err, result) ->
          if err then return res.status(500).send({code: 500, status: "Internal Server Error", reason: err})
          else
            if result[0].artwork == playlist.artwork
              new_albumart = ""
              tracksCollection.find({id: {$in: playlist.songs}}).toArray((err, results) ->
                if err then return res.status(500).send({code: 500, status: "Internal Server Error", reason: err})
                for song in results
                  if song.id.toString() != song_id.toString() && song.artwork != ""
                    new_albumart = song.artwork
                    break;
                console.log "New Album Art Set: "+new_albumart
                playlistCollection.update({id: playlist_id},{$pull: {songs: {id: song_id}}, $set: {artwork: new_albumart}}, (err, result) ->
                  if err then return res.status(500).send({code: 500, status: "Internal Server Error", reason: err})
                  res.status(200).send({code: 200, status: "OKAY"})
                  req.app.locals.motorbot.websocket.broadcast(JSON.stringify({type: 'trackDelete', songId: song_id, playlistId: playlist_id, newAlbumArt: new_albumart}))
                  songQueueCollection.remove({songId: song_id.toString(), playlistId: playlist_id}, (err, results) ->
                    if err then return res.status(500).send({code: 500, status: "Internal Server Error", reason: err})
                    #wss event for queue
                  )
                )
              )
            else
              playlistCollection.update({id: playlist_id},{$pull: {songs: {id: song_id}}}, (err, result) ->
                if err then return res.status(500).send({code: 500, status: "Internal Server Error", reason: err})
                res.status(200).send({code: 200, status: "OKAY"})
                req.app.locals.motorbot.websocket.broadcast(JSON.stringify({type: 'trackDelete', songId: song_id, playlistId: playlist_id}))
                songQueueCollection.remove({songId: song_id.toString(), playlistId: playlist_id}, (err, results) ->
                  if err then return res.status(500).send({code: 500, status: "Internal Server Error", reason: err})
                  #wss event for queue
                )
              )
        )
      else
        return res.status(404).send({code: 404, status: "Playlist Not Found"})
    )
  else
    return res.status(429).send({code: 429, status: "Unauthorized"})
)

module.exports = router