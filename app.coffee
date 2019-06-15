DiscordClient = require './discordClient/discordClient'
WebServer = require './webserver'
motorbotEventHandler = require './motorbotEventHandler'
keys = require './keys.json'

fs = require 'fs'
path = require 'path'

websocketServer = require("ws").Server
MongoClient = require('mongodb').MongoClient
youtubeStream = require 'ytdl-core'
request = require 'request'
cuid = require 'cuid'
readline = require 'readline'
Table = require 'cli-table'
StringArgv = require 'string-argv'
ImageToASCII = require 'asciify-image'

readline.emitKeypressEvents(process.stdin);
if (process.stdin.isTTY)
  process.stdin.setRawMode(true);

class App

  constructor: () ->
    self = @
    @client
    @musicPlayers = {}
    @soundboard = {}
    @say = {}
    @yStream = {}
    @debug_level = "verbose";
    @debug_output_list = [];
    ###if cluster.isMaster
      cluster.on('online', (worker) ->
        console.log('Worker ' + worker.process.pid + ' is online')
      )

      cluster.on('exit', (worker, code, signal) ->
        console.log('Worker ' + worker.process.pid + ' died with code: ' + code + ', and signal: ' + signal)
        console.log('Starting a new worker')
        cluster.fork()
      )

      for i in [0..2]
        cluster.fork()
    else###
    @init()

  debug: (msg,level = "debug") ->
    if (process.env.NODE_ENV != 'test')
      if level == "info"
        level = "\x1b[34m[INFO ]\x1b[0m"
      else if level == "error"
        level = "\x1b[31m[ERROR]\x1b[0m"
      else if level == "warn"
        level = "\x1b[5m\x1b[33m[WARN ]\x1b[0m"
      else if level == "notification"
        level = "\x1b[5m\x1b[35m[NOTIF]\x1b[0m"
      else if level == "debug"
        level = "\x1b[38;5;244m[DEBUG]"
      d = new Date()
      time = "["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"] "
      if @debug_level == "verbose" then console.log(level+time+msg+"\x1b[0m")
      else if @debug_level == "cmd" then @debug_output_list.push(level+time+msg+"\x1b[0m")


  cmd: () ->
    rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
      prompt: "\x1b[34mMotorBot \u2771 \x1b[0m",
      completer: (line) ->
        completions = 'state logs clients voice gateway'.split(' ')
        hits = completions.filter((c) -> c.startsWith(line))
        c = if hits.length then hits else completions
        return [c, line];
    });
    cli_mode = false
    self = @;
    rl.on('line', (input) ->
      if input == ">cli"
        self.client.setDebugLevel("cmd");
        self.debug_level = "cmd";
        readline.cursorTo(process.stdout, 0,0)
        readline.clearScreenDown(process.stdout)
        process.stdout.write('Loading MotorBot CLI...\n');
        process.stdout.write('Creating Interface for Readline\n');
        process.stdout.write('Configuring Interface for Readline\n');
        process.stdout.write('Setting Logging Mode To: cmd\n');
        process.stdout.write('process.stdin.isTTY: '+process.stdin.isTTY+"\n")
        process.stdout.write('Converting MotorBot Icon To ASCII\n');
        process.stdout.write('CLI Width: '+process.stdout.columns+'; CLI Height: '+process.stdout.rows+"\n");
        process.stdout.write('\n')
        ImageToASCII("https://motorbot.io/img/another_icon.png", {
          fit: 'box',
          height: 16,
          c_ratio: 2
        }, (err, converted) ->
          process.stdout.write(converted);
          process.stdout.write('\nWelcome to the MotorBot CLI (version - 0.6.0)\n\nSome Other Info\n\n')
          cli_mode = true
          rl.prompt(true)
        )
      if cli_mode
        args = StringArgv.parseArgsStringToArgv(input);
        #console.log args
        cmd = args[0]
        if cmd == "state"
          newState = "online"
          newStatus = null
          newType = 0
          setting_state = false
          if args.indexOf("-h") > 0 || args.indexOf("--help") > 0
            process.stdout.write("\n"+
              "Usage: state [arguments]\n\n"+
              "Arguments:\n\n"+
              "  -s, --state               set the state of MotorBot, accepts: online, offline, dnd, idle or invisible\n"+
              "  -m, --message, --msg      set status message of MotorBot, this is the text displayed after 'Playing ' or 'Listening to '\n"+
              "  -t, --type                set type of state, accepts: 0, 1 or 2\n\n"+
              "  If no arguments are passed this will return the current state of MotorBot\n\n")
          else
            for c, i in args
              if c == "-s" || c == "--state"
                #set state
                setting_state = true
                newState = args[i+=1]
              else if c == "-m" || c == "--message" || c == "--msg"
                #set status message
                setting_state = true
                newStatus = args[i+=1]
              else if c == "-t" || c == "--type"
                #set status type
                newType = args[i+=1]
            if setting_state
              if newState == "online" || newState == "offline" || newState == "dnd" || newState == "idle" || newState == "invisible"
                self.client.setStatus(newStatus, newType, newState)
                process.stdout.write("\x1b[32m\u25CF\x1b[0m OKAY: State change sent successfully\n")
              else
                process.stdout.write("Incorrect argument passed for the state (-s) option\nExpected: online, offline, dnd, idle or invisible\nGot:"+newState+"\n");
            else
              #return current state
              process.stdout.write("No Arguments Passed?\n")
        else if cmd == "help"
          process.stdout.write("\n"+
            "Usage: [command] -h or --help\n\n"+
            "Commands:\n\n"+
            "  state          alter state of MotorBot\n"+
            "  logs           get logs for MotorBot or DiscordClient Library\n"+
            "  clients        get MotorBot Music connected users\n"+
            "  voice          standard MotorBot voice commands\n"+
            "  gateway        get gateway status\n\n")
        else if cmd == "logs"
          setting_state = false
          which = 0
          level = "verbose"
          if args.indexOf("-h") > 0 || args.indexOf("--help") > 0
            process.stdout.write("\n"+
              "Usage: logs [arguments]\n\n"+
              "Arguments:\n\n"+
              "  -l, --level               only display logs at this or above this level, accepts: verbose, debug, info, notif, warn or error\n"+
              "  -w, --which               select which logs to display, accepts; '\n"+
              "                                                 0, all             show both MotorBot and DiscordClient Library logs\n"+
              "                                                 1                  MotorBot logs\n"+
              "                                                 2                  DiscordClient library logs\n\n"+
              "  If no arguments are passed the default values will be used (level=verbose,which=all)\n\n")
          else
            for c, i in args
              if c == "-l" || c == "--level"
                # only return logs at this or above this level
                # verbose - return all
                #   debug - return all
                #    info - return info and below
                #   notif - return notif and below
                #    warn - return warn and below
                #   error - only return errors
                level = args[i+=1]
              else if c == "-w" || c == "--which"
                # which logs to return
                # 0 | all - all
                #       1 - MotorBot logs
                #       2 - Discord Client logs
                which = args[i+=1]
                if which == "all" then which = 0
                which = parseInt(which)
            print_log = (list) ->
              until list.length == 0
                log_line = list.shift()
                if level == "verbose" || level == "debug"
                  process.stdout.write(log_line+"\n")
                else if level == "info"
                  if log_line.match(/^\[INFO \]/gmi) || log_line.match(/^\[WARN \]/gmi) || log_line.match(/^\[ERROR\]/gmi) || log_line.match(/^\[NOTIF\]/gmi)
                    process.stdout.write(log_line+"\n")
                else if level == "notif"
                  if log_line.match(/^\[WARN \]/gmi) || log_line.match(/^\[ERROR\]/gmi) || log_line.match(/^\[NOTIF\]/gmi)
                    process.stdout.write(log_line+"\n")
                else if level == "warn"
                  if log_line.match(/^\[WARN \]/gmi) || log_line.match(/^\[ERROR\]/gmi)
                    process.stdout.write(log_line+"\n")
                else if level == "error"
                  if log_line.match(/^\[ERROR\]/gmi)
                    process.stdout.write(log_line+"\n")
            if which == 0
              process.stdout.write("--- MotorBot Log ---\n")
              print_log(self.debug_output_list)
              process.stdout.write("--- DiscordClient Library Log ---\n")
              print_log(self.client.utils.output_list)
            else if which == 1
              process.stdout.write("--- MotorBot Log ---\n")
              print_log(self.debug_output_list)
            else if which == 2
              process.stdout.write("--- DiscordClient Library Log ---\n")
              print_log(self.client.utils.output_list)
        else if cmd == "clients"
          process.stdout.write("Connected MotorBot WebSocket Clients: "+self.websocket.connectedClients.length+"\n\n")
          table = new Table({
            style: {'padding-left':1, 'padding-right':1, head:[], border:[]},
            head: ["Socket ID","User ID","Session ID","Since"],
            colWidths: [35, 19, 70, 70]
          })
          if self.websocket.connectedClients.length > 0
            for c in self.websocket.connectedClients
              table.push([c.id,c.user_id,c.session,new Date(c.t)])
            process.stdout.write(table.toString()+"\n\n")
        else if cmd == "voice"
          channelName = undefined
          selected_guild_id = undefined
          joining = false
          leaving = false
          if args.indexOf("-h") > 0 || args.indexOf("--help") > 0
            process.stdout.write("\n"+
              "Usage: voice [arguments]\n\n"+
              "Arguments:\n\n"+
              "  Must contain either join or leave arguments\n\n"+
              "    -j, --join                   join a voice channel\n"+
              "    -l, --leave                  leave a voice channel\n\n"+
              "  -g, --guild                The guild id of the server in which the voice channel is located; This is required for any voice command\n"+
              "  -c, --channel              The channel name of the voice channel MotorBot should join; This is required for the join argument\n\n")
          else
            for c, i in args
              if c == "-j" || c == "--join"
                #joining voice channel
                joining = true
              else if c == "-l" || c == "--leave"
                leaving = true
              else if c == "-g" || c == "--guild"
                selected_guild_id = args[i+=1]
              else if c == "-c" || c == "--channel"
                channelName = args[i+=1]
            if joining && !leaving
              if self.client.guilds[selected_guild_id]
                if channelName
                  for channel in self.client.guilds[selected_guild_id].channels
                    if channel.name == channelName && channel.type == 2
                      channel.join().then((VoiceConnection) ->
                        self.client.voiceConnections[selected_guild_id] = VoiceConnection
                        process.stdout.write("\x1b[32m\u25CF\x1b[0m OKAY: Successfully join voice channel: "+channelName+" ("+channel.id+")\n")
                      )
                      break
                else
                  #join first voice channel
                  for channel in self.client.guilds[selected_guild_id].channels
                    if channel.type == 2
                      channel.join().then((VoiceConnection) ->
                        self.client.voiceConnections[selected_guild_id] = VoiceConnection
                        process.stdout.write("\x1b[32m\u25CF\x1b[0m OKAY: Successfully join voice channel: "+channel.name+"\n")
                      )
                      break
              else
                process.stdout.write("\x1b[31m\u25CF\x1b[0m ERROR: Could not find guild with id: "+selected_guild_id+"\n")
            else if !joining && leaving
              if self.client.guilds[selected_guild_id]
                self.client.leaveVoiceChannel(selected_guild_id)
                process.stdout.write("\x1b[32m\u25CF\x1b[0m OKAY: Left channel in guild "+self.client.guilds[selected_guild_id].name+" ("+selected_guild_id+") successfully\n")
              else
                process.stdout.write("\x1b[31m\u25CF\x1b[0m ERROR: Could not find guild with id: "+selected_guild_id+"\n")
            else
              process.stdout.write("Incorrect arguments passed.\nExpected: Either -j / --join or -l / --leave\nGot: Both\n")
        else if cmd == "gateway"
          type = "status"
          for c, i in args
            if c == "-s" || c == "--status"
              type = "status"
          if type == "status"
            if self.client.internals.pings.length > 2
              rel_pings = self.client.internals.pings.slice(Math.max(self.client.internals.pings.length - 10, 0))
              min_ping = Math.min.apply(null, self.client.internals.pings)
              max_ping = Math.max.apply(null, self.client.internals.pings)
              avg_ping = Math.round((self.client.internals.totalPings / self.client.internals.pings.length)*100)/100
              status = "\x1b[31m\u25CF POOR\x1b[0m"
              if avg_ping < 200
                status = "\x1b[32m\u25CF GOOD\x1b[0m"
              else if avg_ping < 400
                status = "\x1b[33m\u25CF OKAY\x1b[0m"
              process.stdout.write(status+" - GATEWAY CONNECTION \n")
              process.stdout.write("\u251C        Active: \x1b[32mactive (running)\x1b[0m since "+ new Date(self.client.internals.gatewayStart)+"; "+((new Date().getTime() - self.client.internals.gatewayStart)/1000)+"s ago\n")
              process.stdout.write("\u251C Last Sequence: "+self.client.internals.sequence+" ("+self.client.internals.session_id+")\n")
              process.stdout.write("\u251C   Retry Count: "+self.client.internals.connection_retry_count+"\n")
              process.stdout.write("\u2514          PING: Discord Gateway Connection ~ "+self.client.internals.gateway+"\n")

              process.stdout.write("\nPing History - Last "+rel_pings.length+" Pings:\n")
              process.stdout.write("---------------------------------------------------------------------\n")
              i=0
              for p in rel_pings
                process.stdout.write("Heartbeat returned from "+self.client.internals.gateway+": seq="+i+" time="+p+"ms\n")
                i++
              process.stdout.write("---------------------------------------------------------------------\n")
              process.stdout.write("min / max / avg = "+min_ping+"ms / "+max_ping+"ms / "+avg_ping+"ms\n")
              process.stdout.write("---------------------------------------------------------------------\n")

            else
              status = "\x1b[33m\u25CF UNKNOWN\x1b[0m"
              process.stdout.write(status+" - GATEWAY CONNECTION \n");
              process.stdout.write("\x1b[38;5;248m\u2514 Not yet connected long enough, total number of pings: "+self.client.internals.pings.length+"\x1b[0m\n")
        rl.prompt()
    );

  init: () ->
    @debug("Initialising")
    @cmd()
    @client = new DiscordClient({token: keys.token, debug: "verbose"})
    new motorbotEventHandler(@, @client)
    @client.connect()
    self = @
    @initDatabase().then(() ->
      self.initWebServer()
      self.initWebSocket()
      self.initPlaylist()
    )

  initDatabase: () ->
    self = @
    new Promise((resolve, reject) ->
      MongoClient.connect('mongodb://localhost:27017/motorbot', (err, db) ->
        if err
          throw new Error("Failed to connect to database, exiting")
        self.database = db
        self.debug("Connected to Database")
        resolve()
      )
    )

  initWebSocket: () ->
    self = @
    @debug("Initialising WebSocket Connection")
    @websocket = new websocketServer({port: 3006}) #public port is 443 (wss://wss.lolstat.net) and local 3006 via nginx proxy
    @websocket.connectedClients = []
    @websocket.on('connection', (ws) ->
      self.debug("WebSocket Connection")
      session = Buffer(new Date().getTime() + cuid()).toString("base64")
      self.debug("A New WebSocket Connection Has Been Registered: "+session,"info");

      ws.on("close", (e) ->
        self.debug("[WEBSOCKET][/ ][WSS.MOTORBOT.IO]: SOCKET CLOSED","warn")
        self.websocket.connectedClients.forEach((client) ->
          if client
            if client.session == session
              self.websocket.connectedClients.splice(self.websocket.connectedClients.indexOf(client),1)
        )
      )
      ws.on('message', (message) ->
        #recieved message
        self.debug("[WEBSOCKET][<=][WSS.MOTORBOT.IO]: "+message)
        msg = {}
        try
          msg = JSON.parse(message);
        catch e
          console.log message
          console.log e
        switch msg.op
          when 0
            ws.send(JSON.stringify({op: 1, type:"HEARTBEAT_ACK", d:{}}), (err) ->
              if err then console.log err
            )
          when 2
            self.websocket.connectedClients.push({
              id: new Date().getTime() + msg.d.user_id,
              user_id: msg.d.user_id,
              ws: ws,
              session: session,
              t: new Date().getTime()
            })
            welcome_obj = {
              guilds: {},
              session: session
            }
            if self.client.guilds
              guilds = self.client.guilds
              for key, guild of guilds
                if self.client.voiceConnections[guild.id]
                  guilds[key].connected_voice_channel = self.client.voiceConnections[guild.id].channel_name || undefined
                else
                  guilds[key].connected_voice_channel = undefined
              welcome_obj.guilds = guilds #this should be changed to be user specific and only show the ones motorbot is part of
            ws.send(JSON.stringify({op: 3, type:"WELCOME", d:welcome_obj}, (key, value) ->
              if key == "client" then return undefined else return value
            ), (err) ->
              if err then console.log err
            )
          when 8
            #PLAYER_STATE
            cc = undefined
            self.websocket.connectedClients.forEach((client) ->
              if client
                if client.session == msg.d.session
                  cc = client
                  if cc
                    if cc.guild
                      if self.musicPlayers[cc.guild]
                        playlistId = self.musicPlayers[cc.guild].playlist_id
                        songId = self.musicPlayers[cc.guild].song_id
                        player_state = self.musicPlayers[cc.guild].player_state
                        self.debug("PLAYER_STATE requested")
                        if self.musicPlayers[cc.guild].playing
                          ws.send(JSON.stringify({type: 'PLAYER_UPDATE', op: 7, d: {event_type: 'PLAY', player_state: player_state, playlist_id: playlistId, song_id: songId}}))
                        else
                          ws.send(JSON.stringify({type: 'PLAYER_UPDATE', op: 7, d: {event_type: 'PAUSE', player_state: player_state, playlist_id: playlistId, song_id: songId}}))
                      else
                        ws.send(JSON.stringify({type: 'PLAYER_UPDATE', op: 7, d: {event_type: 'STOP', player_state: player_state, playlist_id: undefined, song_id: undefined}}))
                    else
                      self.debug("PLAYER_STATE requested without registering WebSocket connection first", "warn")
                  else
                    self.debug("PLAYER_STATE requested without registering WebSocket connection first", "warn")
            )
          when 10
            #connect to a guild
            self.websocket.connectedClients.forEach((client, i) ->
              if client
                if client.session == msg.d.session
                  self.websocket.connectedClients[i].guild = msg.d.id
                  self.debug("Updating Connected Clients")
                  guild_state_obj = {
                    playing: {},
                    guild: self.client.guilds[msg.d.id],
                    channel: undefined,
                    session: session
                  }
                  songQueueCollection = self.database.collection("songQueue")
                  songQueueCollection.find({status:'playing', guild: msg.d.id}).toArray((err, results) ->
                    if err then console.log err
                    if results[0]
                      results[0][msg.d.id] = false
                      if self.musicPlayers #weird
                        if self.musicPlayers[msg.d.id]
                          results[0]["currently_playing"] = self.musicPlayers[msg.d.id].playing
                          results[0]["start_time"] = self.musicPlayers[msg.d.id].start_time
                          results[0]["position"] = self.musicPlayers[msg.d.id].seekPosition
                          results[0]["playlist_id"] = self.musicPlayers[msg.d.id].playlist_id
                          results[0]["player_state"] = self.musicPlayers[msg.d.id].player_state
                      guild_state_obj.playing = results[0]
                    else
                      guild_state_obj.playing = {currently_playing: false}

                    if self.client.voiceConnections[msg.d.id] then guild_state_obj.channel = self.client.voiceConnections[msg.d.id].channel_name
                    ws.send(JSON.stringify({op: 11, type:"GUILD_STATE", d:guild_state_obj}, (key, value) ->
                      if key == "client" then return undefined else return value
                    ), (err) ->
                      if err then console.log err
                    )
                  )
            )
        )
      )
    @websocket.broadcastByGuildID = (data, guild_id) ->
      if guild_id
        self.websocket.connectedClients.forEach((client) ->
          if client
            if client.guild == guild_id
              client.ws.send(data, (err) ->
                if err then console.log err
              )
        )

    @websocket.broadcast = (data, user_id) ->
      if user_id
        self.websocket.connectedClients.forEach((client) ->
          if client
            if client.user_id == user_id
              client.ws.send(data, (err) ->
                if err then console.log err
              )
        )
      else
        self.websocket.clients.forEach((client) ->
          if client
            client.send(data, (err) ->
              if err then console.log err
            )
        )

  initWebServer: () ->
    self = @
    @debug("Starting Web Server")
    @webserver = new WebServer(@)
    @webserver.start()
    @webserver.site.listen(3210, "localhost", () ->
      self.debug("Web Server Started and Listening on 3210","info")
    ).on("error", (err) ->
      console.log err
    )

  initPlaylist: () ->
    self = @
    songQueueCollection = @database.collection("songQueue")
    songQueueCollection.find({status: "playing"}).toArray((err, results) ->
      if err then console.log err
      for r in results
        trackId = r._id
        songQueueCollection.updateOne({'_id': trackId},{'$set':{'status':'played'}},() ->
          self.debug("Track Status Changed")
        )
    )

  streamNewTrack: (results, guild_id) ->
    self = @
    #guild_id = "130734377066954752"
    songQueueCollection = @database.collection("songQueue")
    tracksCollection = @database.collection("tracks")
    playlistsCollection = @database.collection("playlists")
    if results[0]
      videoId = results[0].video_id
      title = results[0].title
      trackId = results[0]._id
      song_id = results[0].id
      playlistId = results[0].playlistId
      song = results[0]
      if videoId
        songQueueCollection.updateOne({'_id': trackId, 'playlistId': playlistId, guild: guild_id},{'$set':{'status':'playing'}},(err, result) ->
          if !err then self.debug("Track Status Changed")
        )
        tracksCollection.updateOne({'id': song_id},{'$inc':{'play_count':1}},(err, result) ->
          if !err then self.debug("Tracks Play Count increased")
        )
        playlistsCollection.updateOne({'id': playlistId, "songs.id": song_id},{'$inc':{'songs.$.play_count':1}, '$set':{'songs.$.last_played': new Date().getTime()}},(err, result) ->
          if !err then self.debug("Playlist Play Count increased")
        )
        requestUrl = 'https://www.youtube.com/watch?v=' + videoId
        youtubeStream.getInfo(requestUrl, (err, info) ->
          volume = 0.5 #set default, as some videos (recently uploaded maybe?) don't have loudness value
          #stabilise volume to avoid really loud or really quiet playback
          if info
            if info.loudness
              volume = (parseFloat(info.loudness)/-40)
              self.debug "Setting Volume Based on Video Loudness ("+info.loudness+"): "+volume
            self.yStream[guild_id] = youtubeStream.downloadFromInfo(info,{quality: 'highest', filter: 'audioonly'})
            thisystream = self.yStream[guild_id]
            thisystream.on("error", (e) ->
              console.log "e: "+e.toString()
              self.debug("Error Occurred Loading Youtube Video")
              self.websocket.broadcast(JSON.stringify({type: 'YOUTUBE_ERROR', op:6, d: {error: e.toString()}}))
              self.nextSong(guild_id)
            )
            if self.client.voiceConnections[guild_id]
              console.log self.client.voiceConnections
              self.client.voiceConnections[guild_id].playFromStream(thisystream).then((audioPlayer) ->
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
                    self.websocket.broadcast(JSON.stringify({type: 'PLAYER_UPDATE', op: 7, d: {event_type: 'PLAY', player_state: playerState, playlist_id: playlistId, song_id: song_id}}))
                  )
                  self.websocket.broadcast(JSON.stringify({type: 'TRACK_UPDATE', op: 5, d: {event_type: "CHANGE", event_data: song, start_time: new Date().getTime()}}))
                  self.client.setStatus(title)
                  self.debug("Now Playing: "+title)
                )
                self.musicPlayers[guild_id].on("streamPacket", (packet) ->
                  self.websocket.broadcast(JSON.stringify({type: 'TRACK_PACKET', op: 12, d: {event_type: "UPDATE", event_data: {packet}}}))
                )
                self.musicPlayers[guild_id].on("progress", (seconds) ->
                  self.websocket.broadcast(JSON.stringify({type: 'TRACK_DOWNLOAD', op: 10, d: {event_type: "UPDATE", event_data: {download_position: seconds}}}))
                )
                self.musicPlayers[guild_id].on("streamDone", () ->
                  delete self.musicPlayers[guild_id]
                  self.client.setStatus("") # reset to blank
                  self.nextSong(guild_id)
                )
              ).catch((err) ->
                console.log "ERROR OCCURRED CREATING AUDIO PLAYER"
                console.log err
              )
            else
              console.log "Somin aint right here, no voice connection exists for this guild"
          else
            self.debug("Error Occurred Loading Youtube Video")
            self.websocket.broadcast(JSON.stringify({type: 'YOUTUBE_ERROR', op:6, d: {error: "We couldn't retrieve information for this youtube video"}}))
            self.nextSong(guild_id)
        )

  goThroughSongQueue: (guild_id) ->
    self = @
    songQueueCollection = @database.collection("songQueue")
    songQueueCollection.find({status: "queued", guild: guild_id}).sort({sortId: 1}).toArray((err, results) ->
      if err then console.log err
      if results[0]
        self.streamNewTrack(results, guild_id)
      else
        #no songs in queue, go to nextSong
        ###if globals.randomPlayback
          songQueueCollection.find({status: "added"}).sort({randId: 1}).toArray((err, results) ->
            if err then console.log err
            streamNewTrack(results)
          )
        else###
        songQueueCollection.find({status: "added", guild: guild_id}).sort({sortId: 1}).toArray((err, results) ->
          if err then console.log err
          self.streamNewTrack(results, guild_id)
        )
    )

  nextSong: (guild_id) ->
    self = @
    songQueueCollection = @database.collection("songQueue")
    songQueueCollection.find({status: "playing", guild: guild_id}).sort({sortId: 1}).toArray((err, results) ->
      if err then console.log err
      if results[0]
        trackId = results[0]._id
        playlistId = results[0].playlistId
        songQueueCollection.updateOne({'_id': trackId, 'playlistId': playlistId, guild: guild_id},{'$set':{'status':'played'}},() ->
          self.debug("Track Status Changed")
          setTimeout(() ->
            self.goThroughSongQueue(guild_id)
          ,1000)
        )
      else
        self.goThroughSongQueue(guild_id)
    )

  lastSong: (guild_id) ->
      self = @
      songQueueCollection = @database.collection("songQueue")
      songQueueCollection.find({status: "playing", guild: guild_id}).sort({sortId: 1}).toArray((err, results) ->
        if err then console.log err
        if results[0]
          trackId = results[0]._id
          playlistId = results[0].playlistId
          songQueueCollection.updateOne({'_id': trackId, 'playlistId': playlistId, guild: guild_id},{'$set':{'status':'added'}},() ->
            self.debug("Track Status Changed");
            songQueueCollection.find({status: "played", guild: guild_id}).sort({sortId: -1}).toArray((err, results) ->
              if err then console.log err
              if results[0]
                trackId = results[0]._id
                playlistId = results[0].playlistId
                songQueueCollection.updateOne({'_id': trackId, 'playlistId': playlistId},{'$set':{'status':'added'}},() ->
                  self.debug("Track Status Changed");
                  setTimeout(() ->
                    self.goThroughSongQueue(guild_id)
                  ,1000)
                )
              else
                self.debug("No Songs To Go Back To");
            )
          )
        else
          self.goThroughSongQueue(guild_id)
      )

  connectedGuild: (user_id) ->
    self = @
    guild_id = undefined
    for client in self.websocket.connectedClients
      if client
        if client.user_id == user_id
          guild_id = client.guild
          if !guild_id then self.debug("This user isn't connected to a guild currently?")
          return guild_id

  skipSong: (guild_id) ->
    if @musicPlayers[guild_id]
      @musicPlayers[guild_id].stop()
    else
      @nextSong(guild_id)

  backSong: (guild_id) ->
    @lastSong(guild_id)


app = new App()
