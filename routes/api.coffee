express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
globals = require '../models/globals.coffee'
req = require('request')

router.get("/playSong/:trackId", (req, res) ->
  console.log("PlaySong Page Loaded")
  trackId = req.params.trackId
  if !trackId
    res.end(JSON.stringify({success: false, error: "No trackId supplied"}))
  console.log trackId
  trackId = new ObjectID(trackId)
  playlistCollection = globals.db.collection("playlist")
  playlistCollection.update({status: 'added'},{$set: {status: 'played'}}, {multi: true}, (err, result) ->
    if err
      debug("Error Occured Updating Document")
    playlistCollection.find({}).sort({timestamp: 1}).toArray((err, results) ->
      foundTrack = false
      for r in results
        if r._id.toString() == trackId.toString() || foundTrack
          console.log "Found Track"
          playlistCollection.update({timestamp: {$gte: r.timestamp}},{$set: {status: 'added'}}, {multi: true}, (err, result) ->
            if err
              debug("Error Occured Updating Document")
            console.log("Cool, let's play that track")
            globals.dc.stopStream()
            globals.songDone()
            res.end(JSON.stringify({success: true}))
          )
    )
  )
)

router.get("/stopSong", (req, res) ->
  globals.dc.stopStream()
  res.end(JSON.stringify({success: true}))
)

router.get("/playSong", (req, res) ->
  globals.songDone()
  res.end(JSON.stringify({success: true}))
)

router.get("/prevSong", (req, res) ->
  playlistCollection = globals.db.collection("playlist")
  playlistCollection.find({status: {$ne: 'added'}}).sort({timestamp: 1}).toArray((err, results) ->
    lastResult = results[results.length-1]
    secondLastResult = results[results.length-2]
    if lastResult.status == "playing"
      playlistCollection.updateOne({_id: lastResult._id},{$set: {status: 'added'}},(err, result) ->
        if err
          console.log("Databse Updated Error Occured")
        else
          playlistCollection.updateOne({_id: secondLastResult._id},{$set: {status: 'added'}},(err, result) ->
            if err
              console.log("Databse Updated Error Occured")
            else
              globals.dc.stopStream()
              setTimeout(goThroughVideoList,1000)
          )
      )
    else
      playlistCollection.updateOne({_id: lastResult._id},{$set: {status: 'added'}},(err, result) ->
        if err
          console.log("Databse Updated Error Occured")
        else
          globals.dc.stopStream()
          setTimeout(goThroughVideoList,1000)
      )
  )
  res.end(JSON.stringify({success: true}))
)

router.get("/skipSong", (req, res) ->
  globals.dc.stopStream()
  globals.songDone()
  res.end(JSON.stringify({success: true}))
)

router.get("/playlist/:videoId", (request,res) ->
  console.log("Added Item to Playlist")
  videoId = request.params.videoId || ""
  if request.query.userId
    userId = request.query.userId
    channel_id = "169555395860234240" # api_channel otherwise we have to get the user to oAuth, bit of a pain so don't bother
    req.get({
      url: "https://www.googleapis.com/youtube/v3/videos?id="+videoId+"&key=AIzaSyAyoWcB_yzEqESeJm-W_eC5QDcOu5R1M90&part=snippet,contentDetails",
      headers: {
        "Content-Type": "application/json"
      }
    }, (err, httpResponse, body) ->
      if err
        raven.captureException(err,{level:'error',request: httpResponse})
        return console.error('Error Occured Fetching Youtube Metadata')
      data = JSON.parse(body)
      if data.items[0]
        console.log(videoId)
        playlistCollection = globals.db.collection("playlist")
        playlistCollection.insertOne({videoId: videoId, title: data.items[0].snippet.title, duration: data.items[0].contentDetails.duration, channel_id: channel_id, timestamp: new Date().getTime(), status: 'added', userId: userId}, (err, result) ->
          if(err)
            raven.captureException(err,{level:'error'})
            globals.dc.sendMessage(channel_id,":warning: A database error occurred adding this track... <@"+userId+">\nReport sent to sentry, please notify admin of the following error: \`Database insertion error at line 194: "+err.toString()+"\`")
          else
            globals.dc.sendMessage(channel_id,":notes: Added "+data.items[0].snippet.title+" <@"+userId+">")
            globals.songDone()
            res.end(JSON.stringify({added: true}))
        )
      else
        raven.captureException(new Error("Youtube Error: Googleapis returned video not found for videoId"),{level:'error',extra:{videoId: videoId},request: httpResponse})
        globals.dc.sendMessage(channel_id,":warning: Youtube Error: Googleapis returned video not found for videoId ("+videoId+")")
        res.end(JSON.stringify({added: false, error: "Youtube Error"}))
    )
  else
    raven.captureException(new Error("Chrome Extension: No UserId Provided"),{level:'warn',extra:{videoId: videoId}})
    res.end(JSON.stringify({added: false, error: "Authentication Error"}))
)

module.exports = router
