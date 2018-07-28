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
      globals.connectedChannel = chnl_id
      globals.connectedChannelName = chnl
      globals.wss.broadcast(JSON.stringify({type: 'voiceUpdate', status: 'join', channel: chnl}))
      globals.dc.joinVoice(chnl_id,guild_id)
    else if command.match(/leave/)
      globals.connectedChannel = null
      globals.connectedChannelName = null
      globals.wss.broadcast(JSON.stringify({type: 'voiceUpdate', status: 'leave'}))
      globals.dc.leaveVoice(guild_id)

  parseMusicCommand: (msg, command, user_id) ->
    self = @
    if command == "stop"
      globals.dc.stopStream()
      globals.songComplete(false)
    else if command == "playing"
      req.get({url: "https://motorbot.io/api/playing"}, (err, httpResponse, body) ->
        if err
          console.log err
        else
          globals.dc.sendMessage(self.channel_id,"```JSON\n"+body+"\n```")
      )
    else if command == "prev"
      ###playlistCollection = globals.db.collection("playlist")
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
      )###
    else if command == "skip"
      globals.dc.stopStream()
      globals.songComplete(true)
    else if command == "pause"
      globals.dc.pauseStream()
    else if command == "resume"
      globals.dc.resumeStream()
    else if command == "play"
      globals.songComplete(true)
    else if command == "list"
      globals.dc.sendMessage(self.channel_id,":headphones: Playlist can be viewed here: https://motorbot.io/")
    else
      globals.dc.sendMessage(self.channel_id,"Unknown Voice Command :cry:")

module.exports = VoiceCommands
