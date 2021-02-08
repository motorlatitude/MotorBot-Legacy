Pagination = require './pagination.coffee'
Playlist = require './playlist.coffee'
User = require './user.coffee'
Track = require './track.coffee'
SpotifyPlaylists = require './spotifyplaylists.coffee'
Youtube = require './youtube.coffee'

class APIObjects

  constructor:() ->

  pagination:() ->
    return new Pagination()

  playlist:(req) ->
    return new Playlist(req)

  spotifyPlaylists: (req, res) ->
      return new SpotifyPlaylists(req, res)

  youtube: (req) ->
    return new Youtube(req)

  user:(req) ->
    return new User(req)

  track:(req) ->
    return new Track(req)

module.exports = APIObjects