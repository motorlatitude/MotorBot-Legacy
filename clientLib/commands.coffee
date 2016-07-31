globals = require '../models/globals.coffee'
VoiceCommands = require './voiceCommands.coffee'
apiai = require('apiai')
apiai = apiai("ea1bdb33a83f48c795a585e44a4cdb4b") #AI for !talk method

class exports.Commands

  #can set default output channel
  constructor: (@channelId = "169555395860234240") ->
    return true

  parseMessageForCommand: (msg, channel_id = @channelId, user_id = "") ->
    if msg == "!api sid"
      output_msg = "\`\`\`Javascript\nDiscordClient.prototype.internals.sequence = "+globals.dc.internals.sequence+"\n\`\`\`"
      globals.dc.sendMessage(channel_id,output_msg)
    else if msg == "!api vsid"
      output_msg = "\`\`\`Javascript\nDiscordClient.prototype.internals.voice.sequence = "+globals.dc.internals.voice.sequence+"\n\`\`\`"
      globals.dc.sendMessage(channel_id,output_msg)
    else if msg == "!api ssrc"
      output_msg = "\`\`\`Javascript\nDiscordClient.prototype.internals.voice.ssrc = "+globals.dc.internals.voice.ssrc+"\n\`\`\`"
      globals.dc.sendMessage(channel_id,output_msg)
    else if msg == "!api status"
      voice = "Not Connected"
      if globals.dc.internals.voice.endpoint
        voice = globals.dc.internals.voice.endpoint
      output_msg = "All is clear, I'm current connected to Discord Server and everything seems fine :smile:\n\n\`\`\`Javascript\nConnected to Server: \""+globals.dc.internals.gateway+"\"\nMy ID is: "+globals.dc.internals.user_id+"\nConnected to Voice Server: "+voice+"\n\`\`\`"
      globals.dc.sendMessage(channel_id,output_msg)
    else if msg == "!os"
      output_msg = "\`\`\`Javascript\n{\n\tplatform: \""+globals.dc.internals.os.platform()+"\",\n\trelease: "+globals.dc.internals.os.release()+",\n\ttype: \""+globals.dc.internals.os.type()+"\",\n\tloadAvg: "+globals.dc.internals.os.loadavg()+",\n\thostname: \""+globals.dc.internals.os.hostname()+"\",\n\tmemory: \""+Math.round((parseFloat(globals.dc.internals.os.freemem()/1000000)))+"MB / "+Math.round((parseFloat(globals.dc.internals.os.totalmem())/1000000))+"MB\",\n\tarch: "+globals.dc.internals.os.arch()+",\n\tcpus: "+JSON.stringify(globals.dc.internals.os.cpus(), null, '\t')+"\n}\n\`\`\`"
      globals.dc.sendMessage(channel_id,output_msg)
    else if msg == "!os uptime"
      output_msg = "Server Uptime: "+millisecondsToStr(parseFloat(globals.dc.internals.os.uptime())*1000)
      globals.dc.sendMessage(channel_id,output_msg)
    else if msg.match(/cum\son\sme/)
      globals.dc.sendMessage(channel_id,"8====D- -- - (O)")
    else if msg.match(/^!status\s/)
      stt = msg.replace(/!status\s/,"")
      globals.dc.setStatus(stt)
    else if msg.match(/\!random/)
      globals.dc.sendMessage(channel_id,"Random Number: "+(Math.round((Math.random()*100))))
    else if msg.match(/goodnight/gmi)
      globals.dc.sendMessage(channel_id,":sparkles: Good Night <@"+user_id+">")
    else if msg.match(/heads\sor\stails(\?|)/gmi)
      if Math.random() >= 0.5
        globals.dc.sendMessage(channel_id,":one: Heads <@"+user_id+">")
      else
        globals.dc.sendMessage(channel_id,":zero: Tails <@"+user_id+">")
    else if msg.match(/^!ban doug/gmi)
      globals.dc.sendMessage(channel_id,"If only I could :rolling_eyes: <@"+user_id+">")
    else if msg.match(/fight\sme(\sbro|)/gmi) || msg.match(/come\sat\sme(\sbro|)/gmi)
      globals.dc.sendMessage(channel_id,"(ง’̀-‘́)ง")
    else if msg.match(/^!help/gmi)
      globals.dc.sendMessage(channel_id,"<@"+user_id+"> Check this out: https://github.com/motorlatitude/MotorBot/blob/master/README.md")
    else if msg.match(/^!lolstat(\s|\.euw|\.na|\.br|\.eune|\.kr|\.lan|\.las|\.oce|\.ru|\.tr|\.jp)/gmi)
      region = "euw"
      if msg.replace(/^!lolstat/gmi,"").indexOf(".") > -1
        region = msg.replace(/^!lolstat/gmi,"").split(".")[1].split(/\s/gmi)[0]
      summoner = encodeURI(msg.replace(/^!lolstat(\s|\.euw|\.na|\.br|\.eune|\.kr|\.lan|\.las|\.oce|\.ru|\.tr|\.jp)/gmi,"").replace(/\s/gmi,"").toLowerCase())
      globals.dc.sendFile(channel_id,req('https://api.lolstat.net/discord/profile/'+summoner+'/'+region),"",false)
    else if msg.match(/\!voice\s/)
      command = msg.replace(/\!voice\s/,"")
      guild_id = "130734377066954752" #hard coded atm, need to get discord bot to return valid value for guild ID
      vc = new VoiceCommands()
      vc.parseVoiceCommand(command,guild_id)
    else if msg.match(/^!music\s/)
      if globals.dc.internals.voice.ready
        vc = new VoiceCommands()
        command = msg.split(" ")[1]
        vc.parseMusicCommand(msg, command, user_id)
      else
        globals.dc.sendMessage(channel_id,"Hmmmmm, I think you might want to join a Voice Channel first :wink:")
    else if msg.match(/^!volume\s/)
      if globals.dc.internals.voice.ready
        if user_id == "95164972807487488"
          globals.dc.internals.voice.volume = parseFloat(msg.split(/\s/)[1])
        else
          globals.dc.sendMessage("169555395860234240","Sorry, you're not authorised for this command :cry:")
      else
        globals.dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")
    else if msg.match(/^!sb\spog/)
      if globals.dc.internals.voice.ready
        globals.dc.stopStream()
        globals.songDone(false)
        setTimeout(() ->
          globals.dc.playStream(__dirname+'/soundboard/play of the game.mp3',{volume: 3.0})
        ,1000)
      else
        globals.dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")
    else if msg.match(/^!sb\swonder/)
      if globals.dc.internals.voice.ready
        globals.dc.stopStream()
        globals.songDone(false)
        setTimeout(() ->
          globals.dc.playStream(__dirname+'/soundboard/wonder.mp3',{volume: 3.0})
        ,1000)
      else
        globals.dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")
    else if msg.match(/^!sb\s1/)
      if globals.dc.internals.voice.ready
        globals.dc.stopStream()
        globals.songDone(false)
        setTimeout(() ->
          globals.dc.playStream(__dirname+'/soundboard/1.mp3',{volume: 3.0})
        ,1000)
      else
        globals.dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")
    else if msg.match(/^!sb\s2/)
      if globals.dc.internals.voice.ready
        globals.dc.stopStream()
        globals.songDone(false)
        setTimeout(() ->
          globals.dc.playStream(__dirname+'/soundboard/2.mp3',{volume: 3.0})
        ,1000)
      else
        globals.dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")
    else if msg.match(/^!sb\s3/)
      if globals.dc.internals.voice.ready
        globals.dc.stopStream()
        globals.songDone()
        setTimeout(() ->
          globals.dc.playStream(__dirname+'/soundboard/3.mp3',{volume: 3.0})
        ,1000)
      else
        globals.dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")
    else if msg.match(/^!sb\sgp/)
      if globals.dc.internals.voice.ready
        globals.dc.stopStream()
        globals.songDone(false)
        setTimeout(() ->
          globals.dc.playStream(__dirname+'/soundboard/gp.mp3',{volume: 3.0})
        ,1000)
      else
        globals.dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")
    else if msg.match(/^!sb\sj3/)
      if globals.dc.internals.voice.ready
        globals.dc.stopStream()
        globals.songDone()
        setTimeout(() ->
          globals.dc.playStream(__dirname+'/soundboard/justice 3.mp3',{volume: 3.0})
        ,1000)
      else
        globals.dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")
    else if msg.match(/^!sb\ssb/)
      if globals.dc.internals.voice.ready
        globals.dc.stopStream()
        globals.songDone(false)
        setTimeout(() ->
          globals.dc.playStream(__dirname+'/soundboard/speed boost.mp3',{volume: 3.0})
        ,1000)
      else
        globals.dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")
    else if msg.match(/^!sb\swsr/)
      if globals.dc.internals.voice.ready
        globals.dc.stopStream()
        globals.songDone()
        setTimeout(() ->
          globals.dc.playStream(__dirname+'/soundboard/wsr.mp3',{volume: 1.0})
        ,1000)
      else
        globals.dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")
    else if msg.match(/^!sb\saffirmative/)
      if globals.dc.internals.voice.ready
        globals.dc.stopStream()
        globals.songDone(false)
        setTimeout(() ->
          globals.dc.playStream(__dirname+'/soundboard/affirmative.mp3',{volume: 3.0})
        ,1000)
      else
        globals.dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:")
    else if msg.match(/^!talk\s/)
      console.log("Talk Command Issued")
      request = apiai.textRequest(msg.replace(/^!talk\s/,""))
      request.on('response', (response) ->
        console.log(response)
        globals.dc.sendMessage(channel_id,response.result.fulfillment.speech)
      )
      request.on('error', (error) ->
        globals.raven.captureException(error,{level:'error'})
        console.log(error)
      )
      request.end()
    else if msg.match(/^!/)
      globals.dc.sendMessage(channel_id,"I don't know what you want :cry:")