express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
request = require('request')
async = require('async')
uid = require('uuid/v4')

###
  BROWSE ENDPOINT

  https://motorbot.io/api/browse/

  Contains Endpoints:
  - GET: /                                                              - get browse playlists
  - PUT: /youtubeImport                                                 - import youtube playlist
  - PATCH: /youtubeImport/{youtube_playlistId}/playlist/{playlist_id}   - update an imported youtube playlist

  Authentication Required: false
  API Key Required: true
###

#API Key checker
router.use((req, res, next) ->
  if !req.query.api_key
    return res.status(401).send({code: 401, status: "No API Key Supplied"})
  else
    APIAccessCollection = req.app.locals.motorbot.database.collection("apiaccess")
    APIAccessCollection.find({key: req.query.api_key}).toArray((err, results) ->
      if err then console.log err
      if results[0]
        return next()
      else
        return res.status(401).send({code: 401, status: "Unauthorized"})
    )
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

getPlaylistInfo = (youtube_playlistId, youtubePlaylistsHost, youtube_key, callback) ->
  request.get({url: youtubePlaylistsHost+"?part=snippet&id="+youtube_playlistId+"&key="+youtube_key, json: true}, (err, httpResponse, data) ->
    if err then callback(err, undefined)
    if data
      if data.items
        if data.items[0]
          callback(undefined, data.items[0].snippet)
        else
          callback("Playlist Not Found", undefined)
      else
        callback("Playlist Not Found", undefined)
    else
      callback("Playlist Not Found", undefined)
  )

getPlaylistItems = (youtube_playlistId, youtubePlaylistItemsHost, youtube_key, callback, nextPageToken = undefined, videos = []) ->
  url = youtubePlaylistItemsHost+"?part=contentDetails&maxResults=50&playlistId="+youtube_playlistId+"&key="+youtube_key
  if nextPageToken then url = youtubePlaylistItemsHost+"?part=contentDetails&maxResults=50&playlistId="+youtube_playlistId+"&pageToken="+nextPageToken+"&key="+youtube_key
  request.get({url: url, json: true}, (err, httpResponse, data) ->
    if err then callback(err, undefined)
    if data
      if data.items
        if data.items[0]
          for item in data.items
            videos.push(item.contentDetails.videoId)
          if data.nextPageToken
            getPlaylistItems(youtube_playlistId, youtubePlaylistItemsHost, youtube_key, callback, data.nextPageToken, videos)
          else
            if callback then callback(undefined, videos)
        else
          callback("Playlist Not Found", undefined)
      else
        callback("Playlist Not Found", undefined)
    else
      callback("Playlist Not Found", undefined)
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

importingScript = (req, res, playlist_id = undefined) ->
  youtube_playlistId = req.params.youtube_playlistId
  youtubePlaylistsHost = "https://www.googleapis.com/youtube/v3/playlists"
  youtubePlaylistItemsHost = "https://www.googleapis.com/youtube/v3/playlistItems"
  youtube_key = "AIzaSyAyoWcB_yzEqESeJm-W_eC5QDcOu5R1M90"
  browseCollection = req.app.locals.motorbot.database.collection("browse")
  tracksCollection = req.app.locals.motorbot.database.collection("tracks")
  playlistsCollection = req.app.locals.motorbot.database.collection("playlists")
  res.type("json")
  #Get Playlist Info
  getPlaylistInfo(youtube_playlistId, youtubePlaylistsHost, youtube_key, (err, youtube_playlistData) ->
    if err
      console.log err
    else
      #Get Playlist Videos
      getPlaylistItems(youtube_playlistId, youtubePlaylistItemsHost, youtube_key, (err, videos) ->
        if err then console.log err
        if videos
          #Insert Songs
          tracksList = []
          albumartwork = undefined
          user_id = "169554882674556930"
          if !playlist_id then playlist_id = uid()
          io = 1
          async.eachSeries(videos, (video_id, cb) ->
            console.log "Importing "+io+":"+video_id
            io++
            tracksCollection.find({video_id: video_id}).toArray((err, results) ->
              if err then return cb(res.status(500).send({code: 500, status: "Database Error", error: err}))
              ###
              if results[0]
                #song already in tracksCollection
                if results[0].artwork && !albumartwork
                  albumartwork = results[0].artwork
                tracksList.push({
                  id: results[0].id
                  date_added: new Date().getTime()
                  play_count: 0
                  last_played: undefined
                })
                cb()
              else###
              #insert song from source
              request.get({
                url: "https://www.googleapis.com/youtube/v3/videos?id="+video_id+"&key=AIzaSyAyoWcB_yzEqESeJm-W_eC5QDcOu5R1M90&part=snippet,contentDetails",
                json: true
              }, (err, httpResponse, data) ->
                if err
                  return setTimeout(() ->
                    cb(res.status(500).send({code: 500, status: "Youtube API Error", error: err}))
                  ,1000)
                if data.items[0]
                  modifiedTitle = data.items[0].snippet.title.replace(/\[((?!.*?Remix))[^\)]*\]/gmi, '').replace(/\(((?!.*?Remix))[^\)]*\)/gmi, '').replace(/\-(\s|)[0-9]*(\s|)\-/g, '').replace(/(\s|)-(\s|)/gmi," ").replace(/\sFrom\s(.*)\/(|\s)Soundtrack/gmi, "").replace(/(high\squality|\sOST|playlist|\sHD|\sHQ|\s1080p|ft\.|feat\.|ft\s|lyrics|official\svideo|\"|official|video|:|\/Soundtrack\sVersion|\/Soundtrack|\||w\/|\/)/gmi, '')
                  modifiedTitle = encodeURIComponent(modifiedTitle)
                  console.log modifiedTitle
                  request.get({
                    url: "https://api.spotify.com/v1/search?type=track&q="+modifiedTitle,
                    json: true,
                    headers: {
                      "Authorization": "Bearer "+res.locals.spotify_access_token
                    }
                  }, (err, httpResponse, body) ->
                    if err
                      setTimeout(() ->
                        cb(res.status(500).send({code: 500, status: "Spotify API Error", error: err}))
                      ,1000)
                    else
                      console.log body
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
                            if !albumartwork && album_artwork != "" then albumartwork = artwork
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
                      track_id = uid()
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
                        if err
                          setTimeout( () ->
                            cb(res.status(500).send({code: 500, status: "Database Error", error: err}))
                          ,1000)
                        else
                          tracksList.push({
                            id: track_id
                            date_added: new Date().getTime()
                            play_count: 0
                            last_played: undefined
                          })
                          setTimeout(cb,1000)
                      )
                  )
                else
                  setTimeout(() ->
                    console.log "Video Not Found, ignoring"
                    cb()
                  ,1000)
              )
            )
          , (err) ->
            if err then console.log err
            #Done
            art = ""
            if albumartwork then art = albumartwork
            playlistObj =
            {
              id: playlist_id
              name: youtube_playlistData.title
              description: ""
              songs: tracksList
              creator: user_id
              create_date: new Date().getTime()
              followers: [user_id]
              artwork: art
              private: false
              collaborative: false
            }
            playlistsCollection.insertOne(playlistObj, (err, result) ->
              if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
              browseCollection.insertOne({playlist_id: playlist_id}, (err, result) ->
                if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
                res.status(200).send({code: 200, status: "OKAY"}) #INFO Cannot Set Headers after they are sent - request times out and sends 504 before we get here most of the time
              )
            )
          )
      )
  )

router.get("/", (req, res) ->
  res.type("json")
  browseCollection = req.app.locals.motorbot.database.collection("browse")
  browseCollection.find({}).toArray((err, results) ->
    if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
    if results[0]
      playlists = []
      for result in results
        playlists.push(result.playlist_id)
      playlistsCollection = req.app.locals.motorbot.database.collection("playlists")
      playlistsCollection.find({id: {$in: playlists}}).sort({create_date: -1}).limit(20).toArray((err, results) ->
        playlists = results
        playlistsCollection.aggregate({"$match":{"private":false}},{"$project":{"id":"$$ROOT","songs":1,"_id":1}},{"$unwind":"$songs"},{"$group":{"_id": "$_id","totalCount":{"$sum":"$songs.play_count"},"count":{"$sum":1},"playlist":{"$first":"$id"},"totalLastPlayed": {"$sum":"$songs.last_played"}}},{"$project":{"_id":1,"totalCount":1,"count":1,"playlist":1,"popularity":{"$divide":["$totalCount","$count"]}, "avgLastPlayed":{"$divide":["$totalLastPlayed","$count"]}}},{"$sort":{"avgLastPlayed": -1, "popularity":-1}},{"$limit":10}).limit(20).toArray((err, heavy_rotation_playlists) ->
          if err then return res.status(500).send({code: 500, status: "Database Error", error: err})
          if heavy_rotation_playlists[0]
            res.end(JSON.stringify({"spotlight":playlists,"heavy_rotation":heavy_rotation_playlists}))
          else
            res.end(JSON.stringify({"spotlight":playlists,"heavy_rotation":[]}))
        )
      )
    else
      res.status(404).send({code: 404, status: "Nothing To Browse"})
  )
)
#motorbot.io/api/browse/youtubeImport/PLFgquLnL59amEA53mO3KiIJRSNAzO-PRZ/playlist/PqXuY9xcbWduO8Nvf4CwUPtleNAsCcJs?api_key=caf07b8b-366e-44ab-9bda-623f94a9c2df
router.patch("/youtubeImport/:youtube_playlistId/playlist/:playlist_id", refreshSpotifyAccessToken, (req, res) ->
  playlistsCollection = req.app.locals.motorbot.database.collection("playlists")
  playlist_id = req.params.playlist_id
  if playlist_id
    playlistsCollection.remove({id: playlist_id}, (err, result) ->
      importingScript(req, res, playlist_id)
    )
  else
    res.status(400).send({code: 400, status: "Bad Request"})
)

router.put("/youtubeImport/:youtube_playlistId", refreshSpotifyAccessToken, (req, res) ->
  importingScript(req, res)
)

module.exports = router