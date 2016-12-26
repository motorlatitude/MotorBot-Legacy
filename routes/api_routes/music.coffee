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

router.get("/play", (req, res) ->
  res.type('json')
  if req.app.locals.motorbot.musicPlayers["130734377066954752"]
    req.app.locals.motorbot.musicPlayers["130734377066954752"].play()
    req.app.locals.motorbot.websocket.broadcast(JSON.stringify({type: 'playUpdate', status: 'play'}))
    res.sendStatus(200)
  else
    res.sendStatus(400)
)

router.get("/play/song", (req, res) ->
  res.type('json')
  songId = req.query.id;
  playlistId = req.query.playlist_id;
  playlistSort = req.query.sort;
  playlistSortDir = req.query.sort_dir;
  if playlistSortDir == "1"
    playlistSortDir = 1
  else if playlistSortDir == "-1"
    playlistSortDir = -1
  else
    playlistSortDir = 1
  sortObj = {timestamp: 1}
  if playlistSort == "timestamp"
    sortObj = {timestamp: playlistSortDir}
  else if playlistSort == "title"
    sortObj = {title: playlistSortDir}
  else if playlistSort == "artist"
    sortObj = {artist: playlistSortDir}
  else if playlistSort == "album"
    sortObj = {album: playlistSortDir}
  playlistCollection = req.app.locals.motorbot.database.collection("playlists")
  songsCollection = req.app.locals.motorbot.database.collection("songs")
  songQueueCollection = req.app.locals.motorbot.database.collection("songQueue")
  playlistCollection.find({id: playlistId}).toArray((err, results) ->
    if err then console.log err
    if results[0]
      playlist = results[0]
      songsCollection.find({_id: {$in: playlist.songs}}).sort(sortObj).toArray((err, results) ->
        if err then console.log err
        if results[0]
          songsToInsert = []
          inserting = false
          songPlaying = {}
          k = 0
          for song in results
            if song._id.toString() == songId
              song.status = "added"
              song.songId = song._id.toString()
              song.playlistId = playlistId
              songPlaying = song
              song.randId = -1
              song.sortId = k
              inserting = true
            if inserting
              song.status = "added"
              song.songId = song._id.toString()
              song._id = undefined
              song.playlistId = playlistId
              if !song.randId
                song.randId = Math.random()*results.length
              song.sortId = k
              songsToInsert.push(song)
            else
              song.status = "played"
              song.songId = song._id.toString()
              song._id = undefined
              song.playlistId = playlistId
              song.randId = Math.random()*results.length
              song.sortId = k
              songsToInsert.push(song)
            k++
          songQueueCollection.drop()
          songQueueCollection.insert(songsToInsert, (err, results) ->
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
              req.app.locals.motorbot.websocket.broadcast(JSON.stringify({type: 'trackUpdate', song: songPlaying}))
          )
      )
    else
      res.end(JSON.stringify({success: false, message: "Unknown Playlist"}))
  )
)

router.get("/stop", (req, res) ->
  res.type('json')
  if req.app.locals.motorbot.musicPlayers["130734377066954752"]
    req.app.locals.motorbot.musicPlayers["130734377066954752"].stop()
    req.app.locals.motorbot.websocket.broadcast(JSON.stringify({type: 'playUpdate', status: 'stop'}))
    res.sendStatus(200)
  else
    res.sendStatus(400)
)

router.get("/pause", (req, res) ->
  res.type('json')
  if req.app.locals.motorbot.musicPlayers["130734377066954752"]
    req.app.locals.motorbot.musicPlayers["130734377066954752"].pause()
    req.app.locals.motorbot.websocket.broadcast(JSON.stringify({type: 'playUpdate', status: 'pause'}))
    res.sendStatus(200)
  else
    res.sendStatus(400)
)

router.get("/skip", (req, res) ->

)

router.get("/prev", (req, res) ->

)

router.get("/playing", (req, res) ->
  res.type('json')
  songQueueCollection = req.app.locals.motorbot.database.collection("songQueue")
  songQueueCollection.find({status:'playing'}).toArray((err, results) ->
    if err
      res.sendStatus(500)
    if results[0]
      res.end(JSON.stringify(results[0]))
    else
      res.sendStatus(404)
  )
)

module.exports = router