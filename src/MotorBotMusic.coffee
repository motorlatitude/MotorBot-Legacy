
youtubeStream = require 'ytdl-core'

class MotorBotMusic

  constructor: (@app, @Logger) ->
    @yStream = {}
    @musicPlayers = {}

  InitialisePlaylist: () ->
    self = @
    return new Promise((resolve, reject) ->
      songQueueCollection = self.app.Database.collection("songQueue")
      songQueueCollection.find({status: "playing"}).toArray((err, results) ->
        if err then reject(err)
        for r in results
          trackId = r._id
          songQueueCollection.updateOne({'_id': trackId},{'$set':{'status':'played'}},() ->
            self.Logger.write("Track Status Changed")
          )
        resolve()
      )
    )

  streamNewTrack: (results, guild_id) ->
    self = @
    songQueueCollection = @app.Database.collection("songQueue")
    tracksCollection = @app.Database.collection("tracks")
    playlistsCollection = @app.Database.collection("playlists")
    if results[0]
      videoId = results[0].video_id
      title = results[0].title
      trackId = results[0]._id
      song_id = results[0].id
      playlistId = results[0].playlistId
      song = results[0]
      if videoId
        songQueueCollection.updateOne({'_id': trackId, 'playlistId': playlistId, guild: guild_id},{'$set':{'status':'playing'}},(err, result) ->
          if !err then self.Logger.write("Track Status Changed")
        )
        tracksCollection.updateOne({'id': song_id},{'$inc':{'play_count':1}},(err, result) ->
          if !err then self.Logger.write("Tracks Play Count increased")
        )
        playlistsCollection.updateOne({'id': playlistId, "songs.id": song_id},{'$inc':{'songs.$.play_count':1}, '$set':{'songs.$.last_played': new Date().getTime()}},(err, result) ->
          if !err then self.Logger.write("Playlist Play Count increased")
        )
        requestUrl = 'https://www.youtube.com/watch?v=' + videoId
        youtubeStream.getInfo(requestUrl, (err, info) ->
          volume = 0.5 #set default, as some videos (recently uploaded maybe?) don't have loudness value
          #stabilise volume to avoid really loud or really quiet playback
          if info
            if info.loudness
              volume = (parseFloat(info.loudness)/-40)
              self.Logger.write("Setting Volume Based on Video Loudness ("+info.loudness+"): "+volume)
            self.yStream[guild_id] = youtubeStream.downloadFromInfo(info,{quality: 'highest', filter: 'audioonly'})
            thisystream = self.yStream[guild_id]
            thisystream.on("error", (e) ->
              console.log "e: "+e.toString()
              self.Logger.write("Error Occurred Loading Youtube Video")
              self.app.WebSocket.broadcast(JSON.stringify({type: 'YOUTUBE_ERROR', op:6, d: {error: e.toString()}}))
              self.nextSong(guild_id)
            )
            if self.app.Client.voiceConnections[guild_id]
              console.log self.app.Client.voiceConnections
              self.app.Client.voiceConnections[guild_id].playFromStream(thisystream).then((audioPlayer) ->
                self.musicPlayers[guild_id] = audioPlayer
                self.musicPlayers[guild_id].on('ready', () ->
                  self.musicPlayers[guild_id].setVolume(volume)
                  self.musicPlayers[guild_id].play()
                  self.musicPlayers[guild_id].playing = true
                  self.musicPlayers[guild_id].start_time = new Date().getTime()
                  self.musicPlayers[guild_id].playlist_id = playlistId
                  self.musicPlayers[guild_id].song_id = song_id
                  results.shift()
                  playerState = {
                    isPaused: false,
                    isPlaying: true,
                    isStopped: false,
                    restrictions: {},
                    next_tracks: results,
                    previous_tracks: [],
                    current_song: song,
                    seekPosition: 0
                  }
                  if !results[1]
                    playerState.restrictions["skip"] = true
                  songQueueCollection.find({status: "played", guild: guild_id}).sort({sortId: -1}).toArray((err, results) ->
                    if err then console.log err
                    if !results[0]
                      playerState.restrictions["back"] = true
                    else
                      playerState.previous_tracks = results
                    self.musicPlayers[guild_id].player_state = playerState
                    self.app.WebSocket.broadcast(JSON.stringify({type: 'PLAYER_UPDATE', op: 7, d: {event_type: 'PLAY', player_state: playerState, playlist_id: playlistId, song_id: song_id}}))
                  )
                  self.app.WebSocket.broadcast(JSON.stringify({type: 'TRACK_UPDATE', op: 5, d: {event_type: "CHANGE", event_data: song, start_time: new Date().getTime()}}))
                  self.app.Client.setStatus(title)
                  self.Logger.write("Now Playing: "+title)
                )
                self.musicPlayers[guild_id].on("streamPacket", (packet) ->
                  self.app.WebSocket.broadcast(JSON.stringify({type: 'TRACK_PACKET', op: 12, d: {event_type: "UPDATE", event_data: {packet}}}))
                )
                self.musicPlayers[guild_id].on("progress", (seconds) ->
                  self.app.WebSocket.broadcast(JSON.stringify({type: 'TRACK_DOWNLOAD', op: 10, d: {event_type: "UPDATE", event_data: {download_position: seconds}}}))
                )
                self.musicPlayers[guild_id].on("streamDone", () ->
                  delete self.musicPlayers[guild_id]
                  self.app.Client.setStatus("") # reset to blank
                  self.nextSong(guild_id)
                )
              ).catch((err) ->
                self.Logger.write(err,"error")
              )
            else
              self.Logger.write("Somin aint right here, no voice connection exists for this guild","warn")
          else
            self.Logger.write("Error Occurred Loading Youtube Video","error")
            self.app.WebSocket.broadcast(JSON.stringify({type: 'YOUTUBE_ERROR', op:6, d: {error: "We couldn't retrieve information for this youtube video"}}))
            self.nextSong(guild_id)
        )

  goThroughSongQueue: (guild_id) ->
    self = @
    songQueueCollection = @app.Database.collection("songQueue")
    songQueueCollection.find({status: "queued", guild: guild_id}).sort({sortId: 1}).toArray((err, results) ->
      if err then console.log err
      if results[0]
        self.streamNewTrack(results, guild_id)
      else
        songQueueCollection.find({status: "added", guild: guild_id}).sort({sortId: 1}).toArray((err, results) ->
          if err then console.log err
          self.streamNewTrack(results, guild_id)
        )
    )

  nextSong: (guild_id) ->
    self = @
    songQueueCollection = @app.Database.collection("songQueue")
    songQueueCollection.find({status: "playing", guild: guild_id}).sort({sortId: 1}).toArray((err, results) ->
      if err then console.log err
      if results[0]
        trackId = results[0]._id
        playlistId = results[0].playlistId
        songQueueCollection.updateOne({'_id': trackId, 'playlistId': playlistId, guild: guild_id},{'$set':{'status':'played'}},() ->
          self.Logger.write("Track Status Changed")
          setTimeout(() ->
            self.goThroughSongQueue(guild_id)
          ,1000)
        )
      else
        self.goThroughSongQueue(guild_id)
    )

  lastSong: (guild_id) ->
    self = @
    songQueueCollection = @app.Database.collection("songQueue")
    songQueueCollection.find({status: "playing", guild: guild_id}).sort({sortId: 1}).toArray((err, results) ->
      if err then console.log err
      if results[0]
        trackId = results[0]._id
        playlistId = results[0].playlistId
        songQueueCollection.updateOne({'_id': trackId, 'playlistId': playlistId, guild: guild_id},{'$set':{'status':'added'}},() ->
          self.Logger.write("Track Status Changed");
          songQueueCollection.find({status: "played", guild: guild_id}).sort({sortId: -1}).toArray((err, results) ->
            if err then console.log err
            if results[0]
              trackId = results[0]._id
              playlistId = results[0].playlistId
              songQueueCollection.updateOne({'_id': trackId, 'playlistId': playlistId},{'$set':{'status':'added'}},() ->
                self.Logger.write("Track Status Changed");
                setTimeout(() ->
                  self.goThroughSongQueue(guild_id)
                ,1000)
              )
            else
              self.Logger.write("No Songs To Go Back To");
          )
        )
      else
        self.goThroughSongQueue(guild_id)
    )

  skipSong: (guild_id) ->
    if @musicPlayers[guild_id]
      @musicPlayers[guild_id].stop()
    else
      @nextSong(guild_id)

  backSong: (guild_id) ->
    @lastSong(guild_id)

module.exports = MotorBotMusic