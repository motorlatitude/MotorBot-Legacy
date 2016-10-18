globals = require '../models/globals.coffee'
req = require('request')

class VoiceCommands
  #can set default output channel
  constructor: (@channel_id = "169555395860234240") ->
    return true

  parseVoiceCommand: (command, guild_id) ->
    if command.match(/join/)
      chnl = command.replace(/join\s/,"")
      chnl_id = null
      for channel in globals.dc.servers[guild_id].channels
        if chnl == channel.name && channel.type == "voice"
          chnl_id = channel.id
      if chnl_id == null
        chnl = "General"
        for channel in globals.dc.servers[guild_id].channels
          if chnl == channel.name && channel.type == "voice"
            chnl_id = channel.id
      globals.wss.broadcast(JSON.stringify({type: 'voiceUpdate', status: 'join', channel: chnl}))
      globals.dc.joinVoice(chnl_id,guild_id)
    else if command.match(/leave/)
      globals.wss.broadcast(JSON.stringify({type: 'voiceUpdate', status: 'leave'}))
      globals.dc.leaveVoice(guild_id)

  parseMusicCommand: (msg, command, user_id) ->
    self = @
    if command == "stop"
      globals.dc.stopStream()
      globals.songDone(false)
    else if command == "add"
      videoId = msg.split(" ")[2]
      if videoId.indexOf('https://') > -1
        videoId = getParameterByName("v",videoId)
      req.get({
        url: "https://www.googleapis.com/youtube/v3/videos?id="+videoId+"&key=AIzaSyAyoWcB_yzEqESeJm-W_eC5QDcOu5R1M90&part=snippet,contentDetails",
        headers: {
          "Content-Type": "application/json"
        }
      }, (err, httpResponse, body) ->
        if err
          globals.raven.captureException(err,{level:'error',request: httpResponse})
          return console.error('Error Occured Fetching Youtube Metadata')
        data = JSON.parse(body)
        if data.items
          if data.items[0]
            console.log(videoId)
            playlistCollection = globals.db.collection("playlist")
            insertionObj = {videoId: videoId, title: data.items[0].snippet.title, duration: data.items[0].contentDetails.duration, channel_id: self.channel_id, timestamp: new Date().getTime(), status: 'added', userId: user_id}
            playlistCollection.insertOne(insertionObj, (err, result) ->
              if err
                globals.raven.captureException(err,{level: 'error', tags:[{instigator: 'mongo'}]})
                globals.dc.sendMessage(self.channel_id,":warning: A database error occurred adding this track...\nReport sent to sentry, please notify admin of the following error: \`Database insertion error at voiceCommands.coffee:51: "+err.toString()+"\`")
              else
                globals.dc.sendMessage(self.channel_id,":notes: Added "+data.items[0].snippet.title)
                formattedTimestamp = globals.convertTimestamp(data.items[0].contentDetails.duration)
                formattedDiff = "a few seconds"
                globals.wss.broadcast(JSON.stringify({type: 'trackAdd', videoId: videoId, title: data.items[0].snippet.title, duration: data.items[0].contentDetails.duration, formattedTimestamp: formattedTimestamp, formattedDiff: formattedDiff, channel_id: self.channel_id, timestamp: new Date().getTime(), status: 'added', userId: user_id, _id: insertionObj._id.toString()}))
                globals.songDone(true)
            )
          else
            console.log self.channel_id
            globals.dc.sendMessage(self.channel_id,":warning: Youtube Error: Googleapis returned video not found for videoId ("+videoId+")")
            globals.raven.captureException(new Error("Youtube Error: Googleapis returned video not found for videoId"),{level:'error',extra:{videoId: videoId},request: httpResponse})
        else
          console.log self.channel_id
          globals.dc.sendMessage(self.channel_id,":warning: Youtube Error: Googleapis returned video not found for videoId ("+videoId+")")
          globals.raven.captureException(new Error("Youtube Error: Googleapis returned video not found for videoId"),{level:'error',extra:{videoId: videoId},request: httpResponse})
      )
    else if command == "prev"
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
                  console.log("Databse Updated Error Occured")
                else
                  globals.dc.stopStream()
                  globals.songDone(true)
              )
          )
        else
          playlistCollection.updateOne({_id: lastResult._id},{$set: {status: 'added'}},(err, result) ->
            if err
              globals.raven.captureException(err,{level: 'error', tags:[{instigator: 'mongo'}]})
              console.log("Databse Updated Error Occured")
            else
              globals.dc.stopStream()
              setTimeout(() ->
                globals.songDone(true)
              ,1000)
          )
      )
    else if command == "skip"
      globals.dc.stopStream()
      globals.songDone(true)
    else if command == "pause"
      globals.dc.pauseStream()
    else if command == "resume"
      globals.dc.resumeStream()
    else if command == "play"
      globals.songDone(true)
    else if command == "list"
      globals.dc.sendMessage(self.channel_id,":headphones: Playlist can be viewed here: https://mb.lolstat.net/")
    else
      globals.dc.sendMessage(self.channel_id,"Unknown Voice Command :cry:")

module.exports = VoiceCommands
