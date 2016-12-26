express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
globals = require '../../models/globals.coffee'
request = require('request')
async = require('async')
uid = require('rand-token').uid;

###
  PLAYLIST ENDPOINT

  https://mb.lolstat.net/api/playlist/

  Contains Endpoints:
  - playlists
  - by-id

  Authentication Required: true
  API Key Required: true
###

router.get("/playlists", (req, res) ->
  if req.user
    userId = req.user.id
    usersCollection = req.app.locals.motorbot.database.collection("users")
    usersCollection.find({id: userId}).toArray((err, results) ->
      if err then console.log err
      if results[0]
        playlistsCollection = req.app.locals.motorbot.database.collection("playlists")
        playlistsCollection.find({id: {$in: results[0].playlists}}).toArray((err, results) ->
          creators = []
          for playlist in results
            creators.push(playlist.creator)
          playlists = results
          usersCollection.find({id: {$in: creators}}).toArray((err, results) ->
            usersArray = {}
            for user in results
              usersArray[user.id] = {username: user.username, discriminator: user.discriminator}
            for playlist in playlists
              playlist["creatorName"] = usersArray[playlist.creator]
            res.type('json')
            res.end(JSON.stringify(playlists))
          )
        )
      else
        res.sendStatus(403)
    )
  else
    res.sendStatus(403)

)

router.get("/by-id/:playlist_id", (req, res) ->
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
          songsCollection = req.app.locals.motorbot.database.collection("songs")
          songsCollection.find({_id: {$in: playlist.songs}}).toArray((err, results) ->
            if err then console.log err
            finalSongs = []
            songList = {}
            if results[0]
              for song in results
                songList[song._id.toString()] = song
              for song in playlist.songs
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
)

module.exports = router