express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
request = require('request')
async = require('async')
request = require 'request'
cuid = require('cuid')
async = require 'async'
path = require 'path'

utilities = require './objects/APIUtilities.coffee'
APIUtilities = new utilities()
objects = require './objects/APIObjects.coffee'
APIObjects = new objects()

###
  PLAYLIST ENDPOINT

  https://motorbot.io/api/playlist/

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
    APIAccessCollection = req.app.locals.motorbot.Database.collection("apiaccess")
    APIAccessCollection.find({key: req.query.api_key}).toArray((err, results) ->
      if err then console.log err
      if results[0]
        client_id = results[0].id
        if req.headers["authorization"]
          bearerHeader = req.headers["authorization"]
          if typeof bearerHeader != 'undefined'
            bearer = bearerHeader.split(" ")
            bearerToken = bearer[1]
            accessTokenCollection = req.app.locals.motorbot.Database.collection("accessTokens")
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
  songsQueueCollection = req.app.locals.motorbot.Database.collection("songQueue")
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
          req.app.locals.motorbot.WebSocket.broadcast(JSON.stringify(insertionObj))
          res.send({added: true})
        )
      else
        console.log "Songs in queue don't match altered playlist"
        req.app.locals.motorbot.WebSocket.broadcast(JSON.stringify(insertionObj))
        res.send({added: true})
    else
      console.log "Queue Empty"
      req.app.locals.motorbot.WebSocket.broadcast(JSON.stringify(insertionObj))
      res.send({added: true})
  )

refreshSpotifyAccessToken = (req, res, next) ->
  usersCollection = req.app.locals.motorbot.Database.collection("users")
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

router.post("/", (req, res) ->
  res.type("json")
  user_id = req.user_id
  playlistsCollection = req.app.locals.motorbot.Database.collection("playlists")
  usersCollection = req.app.locals.motorbot.Database.collection("users")
  playlist_id = cuid();
  if req.body.playlist_name
    uploadRemainingData = (album_key) ->
      if album_key then album_key = "https://motorbot.io/AlbumArt/"+album_key+".png"
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
              console.log playlistObj
              res.send(playlistObj)
            )
        )
      )
    if req.body.playlist_artwork
      console.log "Album Art Detected"
      albumart_key = cuid();
      req_albumartContent = req.body.playlist_artwork.replace(/^data:([A-Za-z-+/]+);base64,/, '')
      require("fs").writeFile(path.join(__dirname, '../../static/AlbumArt/')+albumart_key+".png", req_albumartContent, 'base64', (err) ->
        if err then console.log(err)
        console.log "Album Art Uploaded"
        uploadRemainingData(albumart_key)
      )
    else
      console.log("No Album Art Detected")
      uploadRemainingData()
  else
    res.send({error: "crap", message:"Incorrectly Formatted Requested"})
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
    tracksCollection = req.app.locals.motorbot.Database.collection("tracks")
    playlistsCollection = req.app.locals.motorbot.Database.collection("playlists")
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
                  track_id = cuid()
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
  playlistCollection = req.app.locals.motorbot.Database.collection("playlists")
  tracksCollection = req.app.locals.motorbot.Database.collection("tracks")

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
  playlistsCollection = req.app.locals.motorbot.Database.collection("playlists")
  usersCollection = req.app.locals.motorbot.Database.collection("users")
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
    filter = APIUtilities.formatFilterForMongo(req.query.filter)
    APIObjects.playlist(req).playlistById(req.params.playlist_id.toString(), filter).then((playlist) ->
      async.parallel([
        (asyncParallelComplete) ->
          if playlist.creator
            APIObjects.user(req).userById(playlist.creator, {username: 1, discriminator: 1}).then((user) ->
              playlist["owner"] = user
              asyncParallelComplete()
            ).catch((error_obj) ->
              asyncParallelComplete(error_obj)
            )
          else
            asyncParallelComplete({error: "PLAYLIST_FORMAT", message: "Unknown playlist format, (playlist is missing an owner)"})
        ,(asyncParallelComplete) ->
          if playlist.songs #return complete song objects for the first 50 tracks, further tracks should be retrieved from the /track endpoint
            songs = playlist.songs.slice(0,100)
            songIds = []
            songsFinal = {}
            for song in songs
              songIds.push(song.id)
              songsFinal[song.id+","+song.date_added] = song #store user variables
              delete songsFinal[song.id+","+song.date_added].id
            APIObjects.track(req).tracksForIds(songIds, {}).then((tracks) ->
              tracks_obj = []
              for SongId, song of songsFinal
                song["track"] = tracks[tracks.findIndex((t) -> if t then return t.id == SongId.split(",")[0] else return undefined)]
                if song.track == undefined || song.track == {}
                  song["track"] = {error: "SONG_NOT_FOUND", message: "The song with this id does not exist"}
                tracks_obj.push(song)
              playlist["tracks"] = APIObjects.pagination().paginate("/playlist/"+req.params.playlist_id+"/tracks", tracks_obj, playlist.songs.length, 0, 100)
              delete playlist.songs
              asyncParallelComplete()
            ).catch((error_obj) ->
              asyncParallelComplete(error_obj)
            )
          else
            # No songs in this playlist
            console.log "PLAYLIST_EMPTY: Playlist contains no songs"
            asyncParallelComplete()
      ], (error_obj) ->
        if error_obj
          res.type("json")
          res.send(JSON.stringify(error_obj))
        else
          res.type("json")
          res.send(JSON.stringify(playlist))
      )
    ).catch((error_obj) ->
      res.type("json")
      res.send(JSON.stringify(error_obj))
    )
  else
    return res.status(401).send({code: 401, status: "Unauthorized"})
)

router.get("/:playlist_id/tracks", (req, res) ->
  if req.user_id
    APIObjects.playlist(req).playlistById(req.params.playlist_id.toString(), {songs: 1}).then((playlist) ->
      if playlist.songs #return complete song objects for the first 50 tracks, further tracks should be retrieved from the /track endpoint
        limit = parseInt(req.query.limit) || 100
        offset = parseInt(req.query.offset) || 0
        if limit < 1
          limit = 1
        else if limit > 100
          limit = 100
        songs = playlist.songs.slice(offset,(offset + limit))
        songIds = []
        songsFinal = {}
        for song in songs
          songIds.push(song.id)
          songsFinal[song.id+","+song.date_added] = song #store user variables
          delete songsFinal[song.id+","+song.date_added].id
        APIObjects.track(req).tracksForIds(songIds).then((tracks) ->
          tracks_obj = []
          for SongId, song of songsFinal
            song["track"] = tracks[tracks.findIndex((t) -> if t then return t.id == SongId.split(",")[0] else return undefined)]
            if song.track == undefined || song.track == {}
              song["track"] = {error: "SONG_NOT_FOUND", message: "The song with this id does not exist"}
            tracks_obj.push(song)
          finalTracks = APIObjects.pagination().paginate("/playlist/"+req.params.playlist_id+"/tracks", tracks_obj, playlist.songs.length, offset, limit)
          finalTracks = APIUtilities.filterResponse(finalTracks,req.query.filter)
          res.type("json")
          res.send(JSON.stringify(finalTracks))

        ).catch((error_obj) ->
          console.log "PLAYLIST_ERROR", error_obj
          res.type("json")
          res.send(JSON.stringify(error_obj))
        )
      else
        # No songs in this playlist
        console.log "PLAYLIST_EMPTY: Playlist contains no songs"

    ).catch((error_obj) ->
      res.type("json")
      res.send(JSON.stringify(error_obj))
    )
  else
    return res.status(401).send({code: 401, status: "Unauthorized"})
)

router.delete("/:playlist_id/song/:song_id", (req, res) ->
  playlistCollection = req.app.locals.motorbot.Database.collection("playlists")
  tracksCollection = req.app.locals.motorbot.Database.collection("tracks")
  songQueueCollection = req.app.locals.motorbot.Database.collection("songQueue")
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
                  req.app.locals.motorbot.WebSocket.broadcast(JSON.stringify({type: 'trackDelete', songId: song_id, playlistId: playlist_id, newAlbumArt: new_albumart}))
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
                req.app.locals.motorbot.WebSocket.broadcast(JSON.stringify({type: 'trackDelete', songId: song_id, playlistId: playlist_id}))
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