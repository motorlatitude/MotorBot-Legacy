express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
globals = require '../models/globals.coffee'
req = require('request')

router.get("/playSong/:trackId", (req, res) ->
  console.log("PlaySong Page Loaded")
  trackId = req.params.trackId
  if !trackId
    return res.end(JSON.stringify({success: false, error: "No trackId supplied"}))
  else
    console.log trackId
    trackId = new ObjectID(trackId)
    playlistCollection = globals.db.collection("playlist")
    playlistCollection.update({status: 'added'},{$set: {status: 'played'}}, {multi: true}, (err, result) ->
      if err
        globals.raven.captureException(err,{level: 'error', tags:[{instigator: 'mongo'}]})
      playlistCollection.find({}).sort({timestamp: 1}).toArray((err, results) ->
        foundTrack = false
        for r in results
          if r._id.toString() == trackId.toString() || foundTrack
            track = r.title
            trackId = r._id.toString()
            trackDuration = r.duration
            playlistCollection.update({timestamp: {$gte: r.timestamp}},{$set: {status: 'added'}}, {multi: true}, (err, result) ->
              if err
                globals.raven.captureException(err,{level: 'error', tags:[{instigator: 'mongo'}]})
              globals.dc.stopStream()
              globals.songDone(true)
              globals.wss.broadcast(JSON.stringify({type: 'trackUpdate', track: track, trackId: trackId, trackDuration: trackDuration}))
              return res.end(JSON.stringify({success: true}))
            )
      )
    )
)

router.get("/stopSong", (req, res) ->
  globals.dc.stopStream()
  globals.songDone(false)
  globals.wss.broadcast(JSON.stringify({type: 'playUpdate', status: 'stop'}))
  res.end(JSON.stringify({success: true}))
)

router.get("/pauseSong", (req, res) ->
  globals.dc.pauseStream()
  globals.wss.broadcast(JSON.stringify({type: 'playUpdate', status: 'pause'}))
  res.end(JSON.stringify({success: true}))
)

router.get("/resumeSong", (req, res) ->
  globals.dc.resumeStream()
  globals.wss.broadcast(JSON.stringify({type: 'playUpdate', status: 'play'}))
  res.end(JSON.stringify({success: true}))
)

router.get("/playSong", (req, res) ->
  globals.songDone(true)
  globals.wss.broadcast(JSON.stringify({type: 'playUpdate', status: 'play'}))
  res.end(JSON.stringify({success: true}))
)

router.get("/prevSong", (req, res) ->
  playlistCollection = globals.db.collection("playlist")
  playlistCollection.find({status: {$ne: 'added'}}).sort({timestamp: 1}).toArray((err, results) ->
    if err
      globals.raven.captureException(err,{level: 'error', tags:[{instigator: 'mongo'}]})
    lastResult = results[results.length-1]
    secondLastResult = results[results.length-2]
    if lastResult.status == "playing"
      playlistCollection.updateOne({_id: lastResult._id},{$set: {status: 'added'}},(err, result) ->
        if err
          console.log("Databse Updated Error Occured")
        else
          playlistCollection.updateOne({_id: secondLastResult._id},{$set: {status: 'added'}},(err, result) ->
            if err
              console.log("Database Updated Error Occurred")
            else
              globals.dc.stopStream()
              setTimeout(goThroughVideoList,1000)
          )
      )
    else
      playlistCollection.updateOne({_id: lastResult._id},{$set: {status: 'added'}},(err, result) ->
        if err
          globals.raven.captureException(err,{level: 'error', tags:[{instigator: 'mongo'}]})
        else
          globals.dc.stopStream()
          setTimeout(() ->
            if goThroughVideoList
              goThroughVideoList
            else
              console.log "Ummmmm, wtf you do?"
          ,1000)
      )
  )
  res.end(JSON.stringify({success: true}))
)

router.get("/skipSong", (req, res) ->
  globals.dc.stopStream()
  globals.songDone(true)
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
        insertionObj = {videoId: videoId, title: data.items[0].snippet.title, duration: data.items[0].contentDetails.duration, channel_id: channel_id, timestamp: new Date().getTime(), status: 'added', userId: userId}
        playlistCollection.insertOne(insertionObj, (err, result) ->
          if(err)
            globals.raven.captureException(err,{level: 'error', tags:[{instigator: 'mongo'}]})
            globals.dc.sendMessage(channel_id,":warning: A database error occurred adding this track... <@"+userId+">\nReport sent to sentry, please notify admin of the following error: \`Database insertion error at api.coffee:111: "+err.toString()+"\`")
          else
            globals.dc.sendMessage(channel_id,":notes: Added "+data.items[0].snippet.title+" <@"+userId+">")
            formattedTimestamp = globals.convertTimestamp(data.items[0].contentDetails.duration)
            formattedDiff = "a few seconds"
            globals.wss.broadcast(JSON.stringify({type: 'trackAdd', videoId: videoId, title: data.items[0].snippet.title, duration: data.items[0].contentDetails.duration, formattedTimestamp: formattedTimestamp, formattedDiff: formattedDiff, channel_id: channel_id, timestamp: new Date().getTime(), status: 'added', userId: userId, _id: insertionObj._id.toString()}))
            globals.songDone(true)
            res.end(JSON.stringify({added: true}))
        )
      else
        globals.raven.captureException(new Error("Youtube Error: Googleapis returned video not found for videoId"),{level:'error',extra:{videoId: videoId},request: httpResponse})
        globals.dc.sendMessage(channel_id,":warning: Youtube Error: Googleapis returned video not found for videoId ("+videoId+")")
        res.end(JSON.stringify({added: false, error: "Youtube Error"}))
    )
  else
    globals.raven.captureException(new Error("Chrome Extension: No UserId Provided"),{level:'warn',extra:{videoId: videoId}})
    res.end(JSON.stringify({added: false, error: "Authentication Error"}))
)

router.get("/deleteSong/:trackId", (req, res) ->
  trackId = req.params.trackId
  playlistCollection = globals.db.collection("playlist")
  playlistCollection.deleteOne({_id: new ObjectID(trackId)}, (err, results) ->
    if err
      globals.raven.captureException(err,{level: 'error', tags:[{instigator: 'mongo'}]})
      res.end(JSON.stringify({success: false, error: "Database Error"}))
    globals.wss.broadcast(JSON.stringify({type: 'trackDelete', trackId: trackId}))
    res.end(JSON.stringify({success: true}))
  )
)

router.get("/playing", (request,res) ->
  playlistCollection = globals.db.collection("playlist")
  playlistCollection.find({status:'playing'}).sort({timestamp: 1}).toArray((err, results) ->
    if err
      globals.raven.captureException(err,{level: 'error', tags:[{instigator: 'mongo'}]})
    if results[0]
      res.end(JSON.stringify(results[0]))
    else
      res.end(JSON.stringify({}))
  )
)

router.get("/playlist", (request, res) ->
  playlistCollection = globals.db.collection("playlist")
  playlistCollection.find({}).sort({timestamp: 1}).toArray((err, results) ->
    if err
      globals.raven.captureException(err,{level: 'error', tags:[{instigator: 'mongo'}]})
    res.end(JSON.stringify(results))
  )
)

module.exports = router
