express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
request = require('request')
async = require('async')
cuid = require('cuid')

###
  MUSIC ENDPOINT

  https://motorbot.io/api/music/

  Contains Endpoints:
  - play
  - stop
  - pause
  - skip
  - prev
  - playing

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

router.get("/play", (req, res) ->
  res.type('json')
  user_id = req.user_id
  if user_id
    guild_id = req.app.locals.motorbot.ConnectedGuild(user_id)
    if guild_id
      musicPlayer = req.app.locals.motorbot.Music.musicPlayers[guild_id]
      if musicPlayer
        musicPlayer.play()
        musicPlayer.playing = true
        if musicPlayer.player_state
          musicPlayer.player_state.isPlaying = true
          musicPlayer.player_state.isStopped = false
          musicPlayer.player_state.isPaused = false
          if musicPlayer.seekPosition
            musicPlayer.player_state.seekPosition = musicPlayer.seekPosition
        req.app.locals.motorbot.WebSocket.broadcastByGuildID(JSON.stringify({type: 'PLAYER_UPDATE', op: 7, d: {event_type: 'PLAY', player_state: musicPlayer.player_state, playlist_id: musicPlayer.playlist_id, song_id: musicPlayer.song_id}}), guild_id)
        res.sendStatus(200)
      else
        res.sendStatus(400)
    else
      res.sendStatus(500)
  else
    res.sendStatus(403)
)

playSongQueue = [] #all play requests get chucked in here, to avoid spam
songQueueStart = new Date().getTime()
songQueueInterval = 1000

scheduleSongPlay = (fn) ->
  if typeof fn == "function" then playSongQueue.push(fn)
  if playSongQueue.length == 0
    #empty queue
  else
    now = new Date().getTime()
    elapsed = now - songQueueStart
    if elapsed > songQueueInterval
      songQueueStart = now
      playSongQueue.shift()()
      setTimeout(scheduleSongPlay,1000)

naturalOrderResults = (resultsFromMongoDB, queryIds) ->
    #Let's build the hashmap
    hashOfResults = resultsFromMongoDB.reduce((prev, curr) ->
        prev[curr.id] = curr
        return prev
    , {})

    return queryIds.map((id) ->
      return hashOfResults[id]
    )

PlaySongs = (req, res, Ids, Offset, PlaylistId, GuildId) ->
  if req.user_id
    UserId = req.user_id;
    console.log("Play These Ids: ", Ids);
    TracksCollection = req.app.locals.motorbot.Database.collection("tracks")
    SongQueueCollection = req.app.locals.motorbot.Database.collection("songQueue")
    TracksCollection.find({"id": {$in: Ids}}).toArray((err, Songs) ->
      if err then res.sendStatus(500)
      if Songs[0]
        Songs = naturalOrderResults(Songs, Ids)
        ModifiedSongs = Songs.map((Song, Index) ->
          Track = Song
          if Index < Offset
            Track.status = "played"
          else
            Track.status = "added"
          Track.songId = Track.id.toString()
          Track.playlistId = PlaylistId
          Track.randId = Math.random() * Songs.length
          Track.sortId = Index
          Track.guild = GuildId
          Track.cuid = cuid()
          delete Track._id
          return Track
        )
        ModifiedSongs.forEach((Track, index) ->
          console.log(Track._id)
        )
        SongQueueCollection.deleteMany({guild: GuildId}, (err) ->
          if err
            res.send(JSON.stringify({success: false, message: err.toString()}))
          SongQueueCollection.insertMany(ModifiedSongs, { forceServerObjectId: true },(err, results) ->
            if err
              res.send(JSON.stringify({success: false, message: err.toString()}))
            else
              res.sendStatus(204)
              if req.app.locals.motorbot.Music.musicPlayers[GuildId]
                req.app.locals.motorbot.Music.yStream[GuildId].end()
                req.app.locals.motorbot.Music.musicPlayers[GuildId].stop()
              else
                req.app.locals.motorbot.Music.nextSong(GuildId)
          )
        )
      else
        res.sendStatus(404)
    )
  else
    res.sendStatus(403)

playSong = (req, res, songId, playlistId, playlistSort, playlistSortDir, guild_id) ->
  user_id = req.user_id
  if user_id
    if guild_id
      if playlistSortDir == "1"
        playlistSortDir = 1
      else if playlistSortDir == "-1"
        playlistSortDir = -1
      else
        playlistSortDir = 1
      sortObj = {}
      if playlistSort == "title"
        sortObj = {title: playlistSortDir}
      else if playlistSort == "artist"
        sortObj = {"artist.name": playlistSortDir}
      else if playlistSort == "album"
        sortObj = {"album.name": playlistSortDir}
      playlistCollection = req.app.locals.motorbot.Database.collection("playlists")
      tracksCollection = req.app.locals.motorbot.Database.collection("tracks")
      songQueueCollection = req.app.locals.motorbot.Database.collection("songQueue")
      playlistCollection.aggregate(
        {$match: {"id":playlistId}},
        {$unwind: "$songs"},
        {$sort: {"songs.date_added": playlistSortDir}},
        {$group: {
          '_id': '$_id',
          'songs': {$push: '$songs'}
        }},
        {$project: {
          "songs": '$songs'
        }}).toArray((err, results) ->
        if err then console.log err
        if results[0]
          playlist = results[0]
          songsList = []
          for song in playlist.songs
            songsList.push(song.id.toString())
          tracksCollection.find({id: {$in: songsList}}).sort(sortObj).toArray((err, results) ->
            if err then console.log err
            if results[0]
              songsToInsert = []
              inserting = false
              songPlaying = {}
              k = 0
              if playlistSort == "timestamp"
                resultsSongs = {}
                for song in results
                  resultsSongs[song.id] = song
                for song_id in songsList
                  song = resultsSongs[song_id]
                  if song
                    song.guild = guild_id
                    if song.id.toString() == songId
                      song.status = "added"
                      song.songId = song.id.toString()
                      song.playlistId = playlistId
                      songPlaying = song
                      song.randId = -1
                      song.sortId = k
                      inserting = true
                    if inserting
                      song.status = "added"
                      song.songId = song.id.toString()
                      song._id = undefined
                      song.playlistId = playlistId
                      if !song.randId
                        song.randId = Math.random()*results.length
                      song.sortId = k
                      songsToInsert.push(song)
                    else
                      song.status = "played"
                      song.songId = song.id.toString()
                      song._id = undefined
                      song.playlistId = playlistId
                      song.randId = Math.random()*results.length
                      song.sortId = k
                      songsToInsert.push(song)
                    k++
              else
                for song in results
                  if song
                    song.guild = guild_id
                    if song.id.toString() == songId
                      song.status = "added"
                      song.songId = song.id.toString()
                      song.playlistId = playlistId
                      songPlaying = song
                      song.randId = -1
                      song.sortId = k
                      inserting = true
                    if inserting
                      song.status = "added"
                      song.songId = song.id.toString()
                      song._id = undefined
                      song.playlistId = playlistId
                      if !song.randId
                        song.randId = Math.random()*results.length
                      song.sortId = k
                      songsToInsert.push(song)
                    else
                      song.status = "played"
                      song.songId = song.id.toString()
                      song._id = undefined
                      song.playlistId = playlistId
                      song.randId = Math.random()*results.length
                      song.sortId = k
                      songsToInsert.push(song)
                    k++
              songQueueCollection.deleteMany({guild: guild_id}, (err) ->
                if err
                  res.end(JSON.stringify({success: false, message: err.toString()}))
                songQueueCollection.insertMany(songsToInsert, (err, results) ->
                  if err
                    res.end(JSON.stringify({success: false, message: err.toString()}))
                  else
                    res.sendStatus(200)
                    #globals.dc.stopStream()
                    if req.app.locals.motorbot.Music.musicPlayers[guild_id]
                      req.app.locals.motorbot.Music.yStream[guild_id].end()
                      req.app.locals.motorbot.Music.musicPlayers[guild_id].stop()
                    else
                      req.app.locals.motorbot.Music.nextSong(guild_id)
                )
              )
            else
              res.end(JSON.stringify({success: false, message: "Tracks Couldn't be Found"}))
          )
        else
          res.end(JSON.stringify({success: false, message: "Unknown Playlist"}))
      )
    else
      res.sendStatus(500)
  else
    res.sendStatus(403)

skipSong = (req, res) ->
  res.type('json')
  user_id = req.user_id
  if user_id
    guild_id = req.app.locals.motorbot.ConnectedGuild(user_id)
    if guild_id
      musicPlayer = req.app.locals.motorbot.Music.musicPlayers[guild_id]
      if musicPlayer
        if musicPlayer.player_state
          if musicPlayer.player_state.next_tracks[0]
            req.app.locals.motorbot.Music.skipSong(guild_id)
            musicPlayer.playing = true
            res.sendStatus(200)
      else
        req.app.locals.motorbot.Music.skipSong(guild_id)
        res.sendStatus(200)
    else
      res.sendStatus(500)
  else
    res.sendStatus(403)

backSong = (req, res) ->
  res.type('json')
  user_id = req.user_id
  if user_id
    guild_id = req.app.locals.motorbot.ConnectedGuild(user_id)
    if guild_id
      musicPlayer = req.app.locals.motorbot.Music.musicPlayers[guild_id]
      if musicPlayer
        if musicPlayer.player_state
          if musicPlayer.player_state.previous_tracks[0]
            req.app.locals.motorbot.Music.backSong(guild_id)
            musicPlayer.playing = true
            res.sendStatus(200)
      else
        req.app.locals.motorbot.Music.backSong(guild_id)
        res.sendStatus(200)
    else
      res.sendStatus(500)
  else
    res.sendStatus(403)

pauseSong = (req, res) ->
  res.type('json')
  user_id = req.user_id
  if user_id
    guild_id = req.app.locals.motorbot.ConnectedGuild(user_id)
    if guild_id
      musicPlayer = req.app.locals.motorbot.Music.musicPlayers[guild_id]
      if musicPlayer
        musicPlayer.pause()
        musicPlayer.playing = false
        if musicPlayer.player_state
          musicPlayer.player_state.isPlaying = false
          musicPlayer.player_state.isStopped = false
          musicPlayer.player_state.isPaused = true
          if musicPlayer.seekPosition
            musicPlayer.player_state.seekPosition = musicPlayer.seekPosition
          req.app.locals.motorbot.WebSocket.broadcastByGuildID(JSON.stringify({type: 'PLAYER_UPDATE', op: 7, d: {event_type: 'PAUSE', player_state: musicPlayer.player_state, playlist_id: musicPlayer.playlist_id, song_id: musicPlayer.song_id}}), guild_id)
          req.app.locals.motorbot.Client.setStatus("")
          res.sendStatus(200)
      else
        res.sendStatus(400)
    else
      res.sendStatus(500)
  else
    res.sendStatus(403)

stopSong = (req, res) ->
  res.type('json')
  user_id = req.user_id
  if user_id
    guild_id = req.app.locals.motorbot.ConnectedGuild(user_id)
    if guild_id
      if req.app.locals.motorbot.Music.musicPlayers[guild_id]
        req.app.locals.motorbot.Music.musicPlayers[guild_id].stop()
        req.app.locals.motorbot.Music.musicPlayers[guild_id].playing = false
        req.app.locals.motorbot.WebSocket.broadcastByGuildID(JSON.stringify({type: 'PLAYER_UPDATE', op: 7, d: {event_type: 'STOP', playlist_id: req.app.locals.motorbot.Music.musicPlayers[guild_id].playlist_id, song_id: req.app.locals.motorbot.Music.musicPlayers[guild_id].song_id}}), guild_id)
        req.app.locals.motorbot.Client.setStatus("")
        res.sendStatus(200)
      else
        res.sendStatus(400)
    else
      res.sendStatus(500)
  else
    res.sendStatus(403)

router.get("/play/song", (req, res) ->
  res.type('json')
  songId = req.query.id;
  playlistId = req.query.playlist_id;
  playlistSort = req.query.sort || "timestamp";
  playlistSortDir = req.query.sort_dir || "1";
  guild = req.query.guild_id
  if req.body.ids
    scheduleSongPlay(PlaySongs(req, res, req.body.ids, req.body.offset, req.body.playlist_id, req.body.guild))
  else
    scheduleSongPlay(playSong(req, res, songId, playlistId, playlistSort, playlistSortDir, guild))
)

router.put("/play/song", (req, res) ->
  res.type('json')
  if req.body.ids
    scheduleSongPlay(PlaySongs(req, res, req.body.ids, req.body.offset, req.body.playlist_id, req.body.guild))
)

router.get("/queue/:song_id/:playlist_id", (req, res) ->
  user_id = req.user_id
  if user_id
    guild_id = req.app.locals.motorbot.ConnectedGuild(user_id)
    if guild_id
      tracksCollection = req.app.locals.motorbot.Database.collection("tracks")
      tracksCollection.find({id: req.params.song_id}).limit(1).toArray((err, results) ->
        if err then console.log err
        if results[0]
          song = results[0]
          song.status = "queued"
          song.songId = song.id.toString()
          song.guild = guild_id
          song._id = undefined
          song.playlistId = req.params.playlist_id
          if !song.randId
            song.randId = Math.random()*results.length
          song.sortId = new Date().getTime()
          songQueueCollection = req.app.locals.motorbot.Database.collection("songQueue")
          songQueueCollection.insertOne(song, (err, results) ->
            if err
              res.end(JSON.stringify({success: false, message: err.toString()}))
            else
              res.sendStatus(204)
              #play if nothing is currently playing
              if req.app.locals.motorbot.Music.musicPlayers[guild_id]
                if !req.app.locals.motorbot.Music.musicPlayers[guild_id].playing
                  req.app.locals.motorbot.Music.yStream[guild_id].end()
                  req.app.locals.motorbot.Music.musicPlayers[guild_id].stop()
              else
                req.app.locals.motorbot.Music.nextSong(guild_id)
          )
      )
    else
      res.sendStatus(500)
  else
    res.sendStatus(403)
)

router.get("/stop", (req, res) ->
  scheduleSongPlay(stopSong(req, res))
)

router.get("/pause", (req, res) ->
  scheduleSongPlay(pauseSong(req, res))
)

router.get("/skip", (req, res) ->
  scheduleSongPlay(skipSong(req, res))
)

router.get("/prev", (req, res) ->
  scheduleSongPlay(backSong(req, res))
)

router.get("/playing", (req, res) ->
  res.type('json')
  user_id = req.user_id
  if user_id
    guild_id = req.app.locals.motorbot.ConnectedGuild(user_id)
    if guild_id
      songQueueCollection = req.app.locals.motorbot.Database.collection("songQueue")
      songQueueCollection.find({status:'playing'}).toArray((err, results) ->
        if err
          res.sendStatus(500)
        if results[0]
          results[0]["currently_playing"] = false
          results[0]["currently_playing"] = req.app.locals.motorbot.Music.musicPlayers[guild_id].playing
          res.end(JSON.stringify(results[0]))
        else
          res.sendStatus(404)
      )
    else
      res.sendStatus(500)
  else
    res.sendStatus(403)
)

module.exports = router