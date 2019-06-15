request = require('request')
async = require 'async'

APIError = require './APIError.coffee'
utilities = require './APIUtilities.coffee'
APIWebsocket = require './APIWebsocket.coffee'

class Youtube

  constructor:(@req) ->

  findVideosForSongsByName: (tracks, importStartTime) ->
    self = @
    APIUtilities = new utilities()
    APIWebSocket_Connection = new APIWebsocket(self.req)
    new Promise((resolve, reject) ->
      videos = {
        found: {}
        not_found: {}
      }
      k = 0
      async.eachSeries(Object.keys(tracks), (track_id, cb) ->
        track = tracks[track_id].track.name
        artist = ""
        if tracks[track_id].track.artists[0] then artist = " "+tracks[track_id].track.artists[0].name
        request({
          url: "https://www.googleapis.com/youtube/v3/search?q="+track+artist+"&maxResults=1&key=AIzaSyAyoWcB_yzEqESeJm-W_eC5QDcOu5R1M90&part=snippet",
          json: true
        }, (err, httpResponse, body) ->
          if err
            console.log "Youtube Error: "+err
            videos["not_found"][track_id] = track
            cb()
          else
            if body && body.items && body.items[0]
              request({
                url: "https://www.googleapis.com/youtube/v3/videos?id="+body.items[0].id.videoId+"&key=AIzaSyAyoWcB_yzEqESeJm-W_eC5QDcOu5R1M90&part=snippet,contentDetails",
                json: true
              }, (err, httpResponse, detailedBody) ->
                if err
                  console.log "Youtube Error: "+err
                  videos["not_found"][track_id] = track
                  cb()
                if detailedBody.items
                  if detailedBody.items[0]
                    video_obj = {
                      video_id: body.items[0].id.videoId,
                      video_title: body.items[0].snippet.title,
                      video_duration: APIUtilities.convertTimestampToSeconds(detailedBody.items[0].contentDetails.duration)
                      track_details: tracks[track_id]
                    }
                    APIWebSocket_Connection.send("SPOTIFY_IMPORT", {
                      type: "UPDATE",
                      start: importStartTime,
                      message: "Finding "+track,
                      progress: (35*(k/Object.keys(tracks).length)+15)/100
                    })
                    videos["found"][track_id] = video_obj
                    cb()
                  else
                    videos["not_found"][track_id] = track
                    cb()
                else
                  videos["not_found"][track_id] = track
                  cb()
                k++
              )
            else
              videos["not_found"][track_id] = track
              cb()
        )
      , (err) ->
        if err then console.log err
        if Object.keys(videos).length > 0
          resolve(videos)
        else
          err = new APIError(self, "No videos found for track list")
          err.code = "YTBERR"
          reject(err)
      )
    )

module.exports = Youtube