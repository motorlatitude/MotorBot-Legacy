Pagination = require './pagination.coffee'
Playlist = require './playlist.coffee'
User = require './user.coffee'
Track = require './track.coffee'

class APIObjects

  constructor:() ->

  pagination:() ->
    return new Pagination()

  playlist:(req) ->
    return new Playlist(req)

  user:(req) ->
    return new User(req)

  track:(req) ->
    return new Track(req)

module.exports = APIObjects