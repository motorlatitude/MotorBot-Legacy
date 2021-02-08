# EXPRESS
express = require 'express'
router = express.Router()

# AUTH METHODS
OAuth = require './auth/oauth.coffee'
PassportSpotify = require './auth/PassportSpotify.coffee'
SpotifyRefreshAccessToken = require './auth/SpotifyRefreshAccessToken.coffee'

# APU UTILITIES
objects = require './objects/APIObjects.coffee'
APIObjects = new objects()
utilities = require './objects/APIUtilities.coffee'
APIUtilities = new utilities()
APIWebsocket = require './objects/APIWebsocket.coffee'


keys = require './../../../../keys.json'

###
  SPOTIFY ENDPOINT

  https://motorbot.io/api/spotify/

  Contains Endpoints:
  - GET / ->                                                              authentication with user
  - GET /callback ->                                                      spotify oauth callback

  - GET /revoke ->                                                        *, **: revoke spotify and MotorBot account connection
  - PATCH /sync ->                                                        *, **: Toggle sync state
  - PUT /playlist/:spotify_playlist_id/owner/:spotify_owner_id ->         *, **: import spotify playlist

  *  Authentication Required: true
  ** API Key Required: true
###

passport = new PassportSpotify()

router.get("/", passport.authenticate('spotify', {scope: ['playlist-read-private', 'playlist-read-collaborative', 'user-read-recently-played', 'user-read-private user-top-read'], session: false}), (req, res) ->
  res.type('json')
)

router.get("/callback", passport.authenticate('spotify', { failureRedirect: keys.baseURL+'/dashboard/account/connections', session: false }), (req, res) ->
  res.redirect(keys.baseURL+"/dashboard/account/connections")
)

router.get("/playlists", new OAuth(), new SpotifyRefreshAccessToken(), (req, res) ->
  res.type("json")
  APIObjects.spotifyPlaylists(req, res).getPlaylists(0, 20, [], (playlists) ->
    return res.status(200).send(playlists)
  )
)

router.get("/revoke", new OAuth(), (req, res) ->
  if req.user
    u = APIObjects.user(req)
    u.userById(req.user_id).then(() ->
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
  usersCollection = req.app.locals.motorbot.Database.collection("users")
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