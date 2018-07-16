express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
globals = require '../../models/globals.coffee'
request = require('request')
async = require('async')
uid = require('rand-token').uid;

###
  MUSIC ENDPOINT

  https://mb.lolstat.net/api/music/

  Contains Endpoints:
  - play
  - stop
  - pause
  - skip
  - prev
  -playing

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

router.get("/play", (req, res) ->
  res.type('json')
  musicPlayer = req.app.locals.motorbot.musicPlayers["130734377066954752"]
  if musicPlayer
    musicPlayer.play()
    musicPlayer.playing = true
    if musicPlayer.player_state
      musicPlayer.player_state.isPlaying = true
      musicPlayer.player_state.isStopped = false
      musicPlayer.player_state.isPaused = false
      if musicPlayer.seekPosition
        musicPlayer.player_state.seekPosition = musicPlayer.seekPosition
    req.app.locals.motorbot.websocket.broadcast(JSON.stringify({type: 'PLAYER_UPDATE', op: 7, d: {event_type: 'PLAY', player_state: musicPlayer.player_state, playlist_id: musicPlayer.playlist_id, song_id: musicPlayer.song_id}}))
    res.sendStatus(200)
  else
    res.sendStatus(400)
)

playSongQueue = [] #all play requests get chucked in here, to avoid spam
songQueueStart = new Date().getTime()
songQueueInterval = 1000

scheduleSongPlay = (fn) ->
  if typeof fn == "funtion" then playSongQueue.push(fn)
  if playSongQueue.length == 0
    #empty queue
  else
    now = new Date().getTime()
    elapsed = now - songQueueStart
    if elapsed > songQueueInterval
      songQueueStart = now
      playSongQueue.shift()()
      setTimeout(scheduleSongPlay,1000)


playSong = (req, res, songId, playlistId, playlistSort, playlistSortDir) ->
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
  playlistCollection = req.app.locals.motorbot.database.collection("playlists")
  tracksCollection = req.app.locals.motorbot.database.collection("tracks")
  songQueueCollection = req.app.locals.motorbot.database.collection("songQueue")
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
          songQueueCollection.drop()
          songQueueCollection.insertMany(songsToInsert, (err, results) ->
            if err
              res.end(JSON.stringify({success: false, message: err.toString()}))
            else
              res.sendStatus(200)
              #globals.dc.stopStream()
              if req.app.locals.motorbot.musicPlayers["130734377066954752"]
                req.app.locals.motorbot.yStream["130734377066954752"].end()
                req.app.locals.motorbot.musicPlayers["130734377066954752"].stop()
              else
                req.app.locals.motorbot.nextSong()
          )
        else
          res.end(JSON.stringify({success: false, message: "Tracks Couldn't be Found"}))
      )
    else
      res.end(JSON.stringify({success: false, message: "Unknown Playlist"}))
  )

skipSong = (req, res) ->
  res.type('json')
  musicPlayer = req.app.locals.motorbot.musicPlayers["130734377066954752"]
  if musicPlayer
    if musicPlayer.player_state
      if musicPlayer.player_state.next_tracks[0]
        req.app.locals.motorbot.skipSong()
        musicPlayer.playing = true
        res.sendStatus(200)
  else
    req.app.locals.motorbot.skipSong()
    res.sendStatus(200)

pauseSong = (req, res) ->
  res.type('json')
  musicPlayer = req.app.locals.motorbot.musicPlayers["130734377066954752"]
  if musicPlayer
    musicPlayer.pause()
    musicPlayer.playing = false
    if musicPlayer.player_state
      musicPlayer.player_state.isPlaying = false
      musicPlayer.player_state.isStopped = false
      musicPlayer.player_state.isPaused = true
      if musicPlayer.seekPosition
        musicPlayer.player_state.seekPosition = musicPlayer.seekPosition
      req.app.locals.motorbot.websocket.broadcast(JSON.stringify({type: 'PLAYER_UPDATE', op: 7, d: {event_type: 'PAUSE', player_state: musicPlayer.player_state, playlist_id: musicPlayer.playlist_id, song_id: musicPlayer.song_id}}))
      req.app.locals.motorbot.client.setStatus("")
      res.sendStatus(200)
  else
    res.sendStatus(400)

stopSong = (req, res) ->
  res.type('json')
  if req.app.locals.motorbot.musicPlayers["130734377066954752"]
    req.app.locals.motorbot.musicPlayers["130734377066954752"].stop()
    req.app.locals.motorbot.musicPlayers["130734377066954752"].playing = false
    req.app.locals.motorbot.websocket.broadcast(JSON.stringify({type: 'PLAYER_UPDATE', op: 7, d: {event_type: 'STOP', playlist_id: req.app.locals.motorbot.musicPlayers["130734377066954752"].playlist_id, song_id: req.app.locals.motorbot.musicPlayers["130734377066954752"].song_id}}))
    req.app.locals.motorbot.client.setStatus("")
    res.sendStatus(200)
  else
    res.sendStatus(400)

router.get("/play/song", (req, res) ->
  res.type('json')
  songId = req.query.id;
  playlistId = req.query.playlist_id;
  playlistSort = req.query.sort || "timestamp";
  playlistSortDir = req.query.sort_dir || "1";
  scheduleSongPlay(playSong(req, res, songId, playlistId, playlistSort, playlistSortDir))
)

router.get("/queue/:song_id/:playlist_id", (req, res) ->
  tracksCollection = req.app.locals.motorbot.database.collection("tracks")
  tracksCollection.find({id: req.params.song_id}).limit(1).toArray((err, results) ->
    if err then console.log err
    if results[0]
      song = results[0]
      song.status = "queued"
      song.songId = song.id.toString()
      song._id = undefined
      song.playlistId = req.params.playlist_id
      if !song.randId
        song.randId = Math.random()*results.length
      song.sortId = new Date().getTime()
      songQueueCollection = req.app.locals.motorbot.database.collection("songQueue")
      songQueueCollection.insertOne(song, (err, results) ->
        if err
          res.end(JSON.stringify({success: false, message: err.toString()}))
        else
          res.sendStatus(204)
          #play if nothing is currently playing
          if req.app.locals.motorbot.musicPlayers["130734377066954752"]
            if !req.app.locals.motorbot.musicPlayers["130734377066954752"].playing
              req.app.locals.motorbot.yStream["130734377066954752"].end()
              req.app.locals.motorbot.musicPlayers["130734377066954752"].stop()
          else
            req.app.locals.motorbot.nextSong()
      )
  )
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
  #TODO
  #WARN
  #INFO
  #TODO this absolutely needs to get done
)

router.get("/playing", (req, res) ->
  res.type('json')
  songQueueCollection = req.app.locals.motorbot.database.collection("songQueue")
  songQueueCollection.find({status:'playing'}).toArray((err, results) ->
    if err
      res.sendStatus(500)
    if results[0]
      results[0]["currently_playing"] = false
      results[0]["currently_playing"] = req.app.locals.motorbot.musicPlayers["130734377066954752"].playing
      res.end(JSON.stringify(results[0]))
    else
      res.sendStatus(404)
  )
)

module.exports = router