var req = require('request'),                         //used to send http requests
    util = require('util'),                           //util
    EE = require('events').EventEmitter,              //event emitter to allow events to be sent to parent
    websocket = require('ws'),                        //web-socket connection
    dgram = require('dgram'),                         //UDP connection
    fs = require('fs'),                               //file system objects
    os = require('os'),                               //system information
    nacl = require('tweetnacl'),                      //encryption
    Opus = require('node-opus'),                      //opus encoding
    zlib = require('zlib'),                           //compression
    childProc = require('child_process'),             //spawn converting process for audio
    keys = require('/var/www/motorbot/keys.json'),    //project tokens
    unpipe = require('unpipe');                       //unpipe spawn
/* Discord Client Class
 * Options (Array Object)
 *  - token: bot authorisation token
 *  - email: user email address
 *  - password: user password
 *  - debug: set to true for logging output (default: false)
 */

var DiscordClient = function (options){
  var self = this;
  EE.call(self);

  //Declare all public variables
  var ws, vws, udpClient, connected = false, hb, vhb, reconnect = false, voiceConnected = false;

  //Initialising
  function init(){
    self.servers = {};
    self.internals = {};
    self.internals.os = os;
    self.internals.voice = {};

    getToken();
  }

  function getToken(){
    if(options.token) return getGateway();

    //TODO user login oauth2 protocol - get user token
  }

  function getGateway(){
    debug("GETing Gateway Server");
    var sPing = new Date().getTime();
    req.get({url: "https://discordapp.com/api/gateway", json: true}, function(err, res, data){
      if(res.statusCode != 200 || err){
        debug("Error Occured Obtaining Gateway Server: "+res.statusCode+" "+res.statusMessage);
        return self.emit("disconnect");
      }
      var ping = new Date().getTime() - sPing;
      debug("Gateway Server: "+data.url+" ("+ping+"ms)");
      return startConnecting(data.url);
    });
  }

  function startConnecting(gateway){
    self.internals.gateway = gateway;
    self.internals.token = options.token;
    ws = new websocket(gateway);

    ws.once('open', handleWSConnection);
		ws.once('close', handleWSClose);
		ws.once('error', handleWSFailure);
		ws.on('message', handleWSMessage);
  }

  /*Handle WS Events*/
  function handleWSFailure(err){
    debug("Error Occured Connecting to Gateway Server: "+err.toString());
    return self.emit("disconnect");
  }

  function handleWSError(err){
    debug("Error Occured Whilst Communicating with the Gateway Server: "+err.toString());
  }

  function handleWSClose(){
    debug("Connection to Gateway Server has CLOSED");
    clearInterval(hb);
    self.connected = false;
    self.emit("disconnect");
    //attempt reconnect with gateway resuming
    setTimeout(function(){
      debug("Attempting to Reconnect");
      self.reconnect = true;
      startConnecting(self.internals.gateway);
    },10000);
  }

  function handleWSConnection(){
    debug("Connected to Gateway Server");
    debug("Using Compression: "+!!zlib.inflateSync);
    var identityPackage = {
      "op": 2,
      "d": {
        "token": self.internals.token,
        "properties": {
            "$os": os.platform(),
            "$browser": "discordClient",
            "$device": "discordClient",
            "$referrer": "",
            "$referring_domain": ""
        },
        "compress": !!zlib.inflateSync,
        "large_threshold": 250
      }
    };
    ws.send(JSON.stringify(identityPackage));
  }

  function handleWSMessage(data, flags){
    //debug("Gateway Server Sent Frame");
    var msg = flags.binary ? JSON.parse(zlib.inflateSync(data).toString()) : JSON.parse(data);
    self.internals.sequence = msg.s;
    //console.log(util.inspect(msg, false, null));
    switch(msg.t){
      case "READY":
        //start sending heartbeat
        //console.log(util.inspect(msg.d, false, null));
        self.internals.session_id = msg.d.session_id;
        self.internals.user_id = msg.d.user.id;
        hb = setInterval(function(){
          var hbPackage = {
            "op": 1,
            "d": self.internals.sequence
          };
          if(ws.readyState === ws.OPEN){
            //debug("Sending Heartbeat with Sequence Identifier: "+self.internals.sequence);
            ws.send(JSON.stringify(hbPackage));
          }
        },msg.d.heartbeat_interval);
        self.connected = true;
        msg.d.guilds.forEach(function(element, i, array){
          self.servers[array[i].id] = {};
        });
        self.emit("ready",msg.d);
        break;
      case "RESUMED":
        debug("Connection To Gateway Succesfully Resumed");
        hb = setInterval(function(){
          var hbPackage = {
            "op": 1,
            "d": self.internals.sequence
          };
          if(ws.readyState === ws.OPEN){
            debug("Sending Heartbeat with Sequence Identifier: "+self.internals.sequence);
            ws.send(JSON.stringify(hbPackage));
          }
        },msg.d.heartbeat_interval);
        self.connected = true;
        self.reconnect = false;
        self.emit("resumed");
        break;
      case "GUILD_CREATE":
        //console.log(util.inspect(msg.d, false, null));
        self.servers[msg.d.id] = msg.d;
        debug("Joined Guild: "+self.servers[msg.d.id].name+" ("+self.servers[msg.d.id].presences.length+" online / "+(parseInt(self.servers[msg.d.id].member_count)-self.servers[msg.d.id].presences.length)+" offline)");
        break;
      case "MESSAGE_CREATE":
        self.emit("message",msg.d.content,msg.d.channel_id,msg.d.author.id,msg.d);
        break;
      case "TYPING_START":
        debug("Typing Event Initiated By user <@"+msg.d.user_id+">");
        self.emit("typing",msg.d);
        break;
      case "PRESENCE_UPDATE":
        self.emit("status",msg.d.user.id,msg.d.status,msg.d.game,msg.d);
        break;
      case "CHANNEL_UPDATE":
        debug("A CHANNEL_UPDATE event was fired (One of the channels was edited)");
        break;
      case "VOICE_STATE_UPDATE":
        var userFound = false;
        self.servers[msg.d.guild_id].voice_states.forEach(function(elem, j, voiceStates){
          if(msg.d.user_id == voiceStates[j].user_id){
            //this is the updating user
            userFound = true;
            if(msg.d.self_mute != voiceStates[j].self_mute){
              if(msg.d.self_mute){
                debug("The user <@"+msg.d.user_id+"> has muted themselves in the channel <#"+msg.d.channel_id+">");
              }
              else{
                debug("The user <@"+msg.d.user_id+"> has un-muted themselves in the channel <#"+msg.d.channel_id+">");
              }
            }
            if(msg.d.self_deaf != voiceStates[j].self_deaf){
              if(msg.d.self_deaf){
                debug("The user <@"+msg.d.user_id+"> has deafend themselves in the channel <#"+msg.d.channel_id+">");
              }
              else{
                debug("The user <@"+msg.d.user_id+"> has un-deafend themselves in the channel <#"+msg.d.channel_id+">");
              }
            }
            if(msg.d.mute != voiceStates[j].mute){
              if(msg.d.mute){
                debug("The user <@"+msg.d.user_id+"> was server-muted in the channel <#"+msg.d.channel_id+">");
              }
              else{
                debug("The user <@"+msg.d.user_id+"> was server-un-muted in the channel <#"+msg.d.channel_id+">");
              }
            }
            if(msg.d.deaf != voiceStates[j].deaf){
              if(msg.d.deaf){
                debug("The user <@"+msg.d.user_id+"> was server-deafend in the channel <#"+msg.d.channel_id+">");
              }
              else{
                debug("The user <@"+msg.d.user_id+"> was server-un-deafend in the channel <#"+msg.d.channel_id+">");
              }
            }
            if(msg.d.channel_id != voiceStates[j].channel_id){
              if(msg.d.channel_id == null){
                debug("The user <@"+msg.d.user_id+"> has left the voice channel <#"+voiceStates[j].channel_id+">");
                //remove presence indicator in server list
                self.servers[msg.d.guild_id].voice_states.splice(j,1);
              }
              else{
                debug("The user <@"+msg.d.user_id+"> has switched to a new voice channel <#"+msg.d.channel_id+">");
              }
            }
            //update serve presence dataSet
            self.servers[msg.d.guild_id].voice_states[j] = msg.d;
          }
        });

        if(!userFound){
          debug("The user <@"+msg.d.user_id+"> has joined the voice channel <#"+msg.d.channel_id+">");
          self.servers[msg.d.guild_id].voice_states.push(msg.d);
        }
        //debug("A VOICE_STATE_UPDATE event occured (likely joining or leaving a call / muting or deafening)");
        //console.log(util.inspect(msg.d, false, null));
        break;
      case "VOICE_SERVER_UPDATE":
        debug("A VOICE_SERVER_UPDATE event occured (user / bot joined voice channel)");
        self.voiceConnected = true;
        self.internals.voice = {
          "token": msg.d.token,
          "guild_id": msg.d.guild_id,
          "endpoint": msg.d.endpoint,
          "user_id": self.internals.user_id,
          "session_id": self.internals.session_id
        };
        //console.log(util.inspect(msg, false, null));
        debug("Generating New Websocket Connection to Voice Gateway");
        vws = new websocket("wss://"+msg.d.endpoint.split(":")[0]);
        vws.once('open', handleVoiceWSConnection);
    		vws.once('close', handleVoiceWSClose);
    		vws.once('error', handleVoiceWSFailure);
    		vws.on('message', handleVoiceWSMessage);
        break;
      case "INVALID_SESSION":
        debug("An op 9 package was recieved from the gateway server (Invalid Session Id)");
        debug("Connection will terminate");
        break;
      default:
        console.log(util.inspect(msg, false, null));
        break;
    }
  }

  //Voice Websocket Events
  function handleVoiceWSConnection(){
    //send op 0 identity package
    var identityPackage = {
      "op": 0,
      "d" :{
            "server_id": self.internals.voice.guild_id,
            "user_id": self.internals.voice.user_id,
            "session_id": self.internals.voice.session_id,
            "token": self.internals.voice.token
            }
    };
    vws.send(JSON.stringify(identityPackage));
  }

  function handleVoiceWSFailure(err){
    debug("Error Occured Connecting to Voice Gateway Server: "+err.toString());
    clearInterval(vhb);
  }

  function handleVoiceWSClose(){
    debug("Connection to Voice Gateway Server is CLOSED");
    self.emit("voiceClosed");
    clearInterval(vhb);
    vhb = null;
  }

  function handleVoiceWSMessage(data, flags){
    //debug("Voice Gateway Server Sent Frame");
    var msg = flags.binary ? JSON.parse(zlib.inflateSync(data).toString()) : JSON.parse(data);
    switch(msg.op){
      case 2:
        vhb = setInterval(function(){
          var vhbPackage = {
            "op": 3,
            "d": null
          };
          if(vws.readyState === vws.OPEN){
            //debug("Sending Voice Heartbeat with Sequence Identifier: null");
            vws.send(JSON.stringify(vhbPackage));
          }
        },msg.d.heartbeat_interval);

        console.log(util.inspect(msg.d, false, null));

        debug("SSRC VALUE: "+msg.d.ssrc);
        self.internals.voice.udpClient = dgram.createSocket('udp4');
        //retrieve local IP by sending ssrc with an otherwise empty 72 byte packet
        var udpDiscPacket = Buffer.alloc(70); //70 byte packet - for some reason
        udpDiscPacket.writeUIntBE(parseInt(msg.d.ssrc), 0, 4);
        self.internals.voice.port = msg.d.port;
        self.internals.voice.ssrc = msg.d.ssrc;
        self.internals.voice.udpClient.send(udpDiscPacket, 0, udpDiscPacket.length, parseInt(msg.d.port), self.internals.voice.endpoint.split(":")[0], function(err, bytes) {
            if (err) throw err;
            debug('UDP message sent to ' + self.internals.voice.endpoint.split(":")[0] +':'+ msg.d.port);
        });

        self.internals.voice.udpClient.once('message', function (msg, rinfo) {
            debug("UDP Package Recieved From: "+rinfo.address + ':' + rinfo.port);
            var buffArr = JSON.parse(JSON.stringify(msg)).data;
            //Parse received packet for client ip and port number
            var vDiscIP = "";
      			for (var i=4; i<buffArr.indexOf(0, i); i++) {
      				vDiscIP += String.fromCharCode(buffArr[i]);
      			}
      			vDiscPort = msg.readUIntLE(msg.length - 2, 2).toString(10);

    				var wsDiscPayload = {
    					"op":1,
    					"d":{
    						"protocol":"udp",
    						"data":{
      						"address": vDiscIP,
      						"port": parseInt(vDiscPort),
    							"mode": "xsalsa20_poly1305"
    						}
    					}
      			};
            //console.log(util.inspect(wsDiscPayload, false, null));
      			vws.send(JSON.stringify(wsDiscPayload));
        });
        break;
      case 3: //return HB

        break;
      case 4: //session description
        //console.log(util.inspect(msg, false, null));
        self.internals.voice.secretKey = msg.d.secret_key;
        self.internals.voice.mode = msg.d.mode;
        self.internals.voice.ready = true;
        self.internals.voice.sequence = 0;
        self.internals.voice.timestamp = 0;
        self.internals.voice.allowPlay = false;
        self.internals.voice.pause = false;
        self.internals.voice.pauseData = null;
        self.emit("voiceReady");
        break;
      case 5: //user speaking - irrelevant atm

        break;
      default:
        console.log(util.inspect(msg, false, null));
    }
  }

  //Public Methods
  self.playStream = function(stream, options){
    if(!self.internals.voice.pause){
      var volume = 0.5;
      if(options){
        if(options.volume){
          if(options.volume > 100000000){
            volume = 100000000;
          }
          else{
            volume = options.volume;
          }
        }
      }
      self.internals.voice.volume = volume;
      self.stopStream(function(){
        self.internals.voice.allowPlay = true;
        if(self.internals.voice.ready){
          var encoded, startTime;
          opusEncoder = new Opus.OpusEncoder(48000, 2);
          var nonce = new Buffer(24);
          var onWarning = false;
          var onSendEmpty = false;
          nonce.fill(0);
          VoicePacket = function(data){
            var mac = self.internals.voice.secretKey ? 16 : 0;
        		var packetLength = data.length + 12 + mac;

        		var audioBuffer = data;
        		var returnBuffer = new Buffer(packetLength);

        		returnBuffer.fill(0);
        		returnBuffer[0] = 0x80;
        		returnBuffer[1] = 0x78;

        		returnBuffer.writeUIntBE(self.internals.voice.sequence, 2, 2);
        		returnBuffer.writeUIntBE(self.internals.voice.timestamp, 4, 4);
        		returnBuffer.writeUIntBE(self.internals.voice.ssrc, 8, 4);

        		if (self.internals.voice.secretKey) {
        			// copy first 12 bytes
        			returnBuffer.copy(nonce, 0, 0, 12);
        			audioBuffer = nacl.secretbox(new Uint8Array(data), new Uint8Array(nonce), new Uint8Array(self.internals.voice.secretKey));
        		}

        		for (var i = 0; i < audioBuffer.length; i++) {
        			returnBuffer[i + 12] = audioBuffer[i];
        		}

        		return returnBuffer;
          };

          function sendAudio(opusEncoder, cnt){
            if(self.internals.voice.ready && self.internals.voice.allowPlay){
              //console.log("SendAudio");
              var buff, encoded, audioPacket, nextTime, channels = 2;
              //console.log(streamOutput.read(1920*2));
              buff = self.internals.voice.streamOutput.read(1920*channels);
              /*if(!buff){
                if(onWarning){
                  console.log("[!] Empty Buffer Error");
                  setTimeout(function(){sendAudio(opusEncoder, cnt)}, 200);
                  return;
                }
                else{
                  onWarning = true;
                  setTimeout(function(){sendAudio(opusEncoder, cnt)}, 200);
                  return;
                }
              }*/
              if(self.internals.voice.streamOutput.destroyed && self.internals.voice.pauseData == null) return;
              self.internals.voice.sequence + 1 < 65535 ? self.internals.voice.sequence += 1 : self.internals.voice.sequence = 0;
              self.internals.voice.timestamp + 960 < 4294967295 ? self.internals.voice.timestamp += 960 : self.internals.voice.timestamp = 0;
              if (buff && buff.length !== 1920 * channels) {
      					var newBuffer = new Buffer(1920 * channels).fill(0);
      					buff.copy(newBuffer);
      					buff = newBuffer;
      				}
              if(buff){
                let out = new Buffer(buff.length);
                let multiplier =  Math.pow(self.internals.voice.volume, 1.660964);
            		for (let i = 0; i < buff.length; i += 2) {
            			if (i >= buff.length - 1) {
            				break;
            			}
            			let uint = Math.floor(multiplier * buff.readInt16LE(i));
            			// Ensure value stays within 16bit
            			uint = Math.min(32767, uint);
            			uint = Math.max(-32767, uint);
            			// Write 2 new bytes into other buffer;
            			out.writeInt16LE(uint, i);
            		}
                buff = out;
                encoded = opusEncoder.encode(buff, 1920);
                audioPacket = VoicePacket(encoded);
                if(self.internals.voice.pause){ //if paused store voicepackets in pauseData
                  if(self.internals.voice.pauseData == null) self.internals.voice.pauseData = [];
                  self.internals.voice.pauseData.push(audioPacket);
                  if(!onSendEmpty){
                    debug("Sending Empty Packet Before Pause");
                    var emptyBuffer = new Buffer([0xF8, 0xFF, 0xFE]);
                    onSendEmpty = true;
                    self.internals.voice.udpClient.send(emptyBuffer, 0, emptyBuffer.length, self.internals.voice.port, self.internals.voice.endpoint.split(":")[0], function(err, bytes) {
                        if (err) throw err;
                        //debug('UDP message sent to ' + self.internals.voice.endpoint.split(":")[0] +':'+ self.internals.voice.port);
                    });
                    self.emit("paused");
                  }
                }
                else{
                  if(self.internals.voice.pauseData != null && self.internals.voice.pauseData.length > 0){ //play pauseData if available
                    self.internals.voice.pauseData.push(audioPacket);
                    var voicePacket = self.internals.voice.pauseData.shift();
                    if(voicePacket){
                      self.internals.voice.udpClient.send(voicePacket, 0, voicePacket.length, self.internals.voice.port, self.internals.voice.endpoint.split(":")[0], function(err, bytes) {
                          if (err) throw err;
                          onSendEmpty = false;
                          //debug('UDP message sent to ' + self.internals.voice.endpoint.split(":")[0] +':'+ self.internals.voice.port);
                      });
                      self.emit("songTime",cnt*20);
                    }
                    else if(self.internals.voice.pauseData.length < 1){
                      self.internals.voice.pauseData = null;
                    }
                  }
                  else{ //if no pause data and not paused play as normal
                    self.internals.voice.udpClient.send(audioPacket, 0, audioPacket.length, self.internals.voice.port, self.internals.voice.endpoint.split(":")[0], function(err, bytes) {
                        if (err) throw err;
                        //debug('UDP message sent to ' + self.internals.voice.endpoint.split(":")[0] +':'+ self.internals.voice.port);
                    });
                    self.emit("songTime",cnt*20);
                  }
                }
              }
              else if(!self.internals.voice.pause && self.internals.voice.pauseData != null && self.internals.voice.pauseData.length > 0){
                var voicePacket = self.internals.voice.pauseData.shift();
                if(voicePacket){
                  self.internals.voice.udpClient.send(voicePacket, 0, voicePacket.length, self.internals.voice.port, self.internals.voice.endpoint.split(":")[0], function(err, bytes) {
                      if (err) throw err;
                      onSendEmpty = false;
                      if(self.internals.voice.pauseData){
                        if(self.internals.voice.pauseData.length < 1){
                          self.internals.voice.pauseData = null;
                          self.emit("songDone");
                          self.stopStream();
                        }
                      }
                      //debug('UDP message sent to ' + self.internals.voice.endpoint.split(":")[0] +':'+ self.internals.voice.port);
                  });
                  self.emit("songTime",cnt*20);
                }
                else if(self.internals.voice.pauseData.length < 1){
                  self.internals.voice.pauseData = null;
                }
              }
              nextTime = startTime + (cnt+1) * 20;
              return setTimeout(function() {
        				return sendAudio(opusEncoder, cnt + 1);
        			}, 20 + (nextTime - new Date().getTime()));
            }
          }
          if(typeof(stream) == "string"){
            self.internals.voice.enc = childProc.spawn('ffmpeg' , [
              '-hide_banner',
      				'-i', stream,
      				'-f', 's16le',
      				'-ar', '48000',
              '-ss', 0,
      				'-ac', 2,
      				'pipe:1'
      			]).on("error",function(e){
              console.log("ERROR");
            });
          }
          else{
            self.internals.voice.enc = childProc.spawn('ffmpeg' , [
              '-hide_banner',
              '-i', '-',
              '-f', 's16le',
              '-ar', '48000',
              '-ss', 0,
              '-ac', 2,
              'pipe:1'
            ]).on("error",function(e){
              console.log("ERROR");
            });
            self.internals.voice.stream = stream;
            self.internals.voice.stream.pipe(self.internals.voice.enc.stdin);
            /*self.internals.voice.stream.on('error', function(code, signal) {
              console.log("[!] STREAM ERROR");
      			});*/
          }
    			self.internals.voice.enc.stdout.once('end', function() {
            console.log("[!] Stdout Ended");
            if(self.internals.voice.enc){
      				self.internals.voice.enc.kill();
              self.internals.voice.stream = null;
              self.internals.voice.enc = null;
              if(self.internals.voice.pauseData == null){
                self.stopStream();
              }
            }
    			});
          /*process.stdout.on('error', function( err ) {
            console.log("STDOUT ERROR: "+e);
          });*/
          /*self.internals.voice.enc.once('exit', function(code, signal) {
            console.log("[!] Enc Exited");
    			});*/
          self.internals.voice.enc.on('error', function(error) {
            console.log("[!] ENC ERROR: "+error);
    			});
          /*self.internals.voice.enc.once('disconnect', function() {
            console.log("[!] Stdout Disconnected");
    			});*/
          self.internals.voice.enc.once('close', function(code, signal) {
            console.log("[!] Stdout Closed");
            if(self.internals.voice.pauseData == null){
              self.emit("songDone");
            }
    			});
    			self.internals.voice.enc.stdout.once('error', function(e) {
            console.log("[!] Stdout Disconnected");
            if(self.internals.voice.enc){
      	      self.internals.voice.enc.stdout.emit('end');
            }
    			});
          self.internals.voice.enc.stderr.on('data', function(data){
            //console.log('data: '+data);
          });
    			self.internals.voice.enc.stdout.once('readable', function() {
            if(self.internals.voice.enc){
              self.internals.voice.pipeStream = this;
              self.setSpeaking(true);
              startTime = new Date().getTime();
              self.internals.voice.streamOutput = self.internals.voice.enc.stdout;
              sendAudio(opusEncoder,1);
            }
    			});
        }
      });
    }
  };

  self.pauseStream = function(){
    self.setSpeaking(false);
    self.internals.voice.pause = true
  };

  self.resumeStream = function(){
    self.setSpeaking(true);
    self.internals.voice.pause = false
  };

  self.setSpeaking = function(value){
    var wsSpeaking = {
      "op":5,
      "d":{
        "speaking": value,
        "delay": 0
      }
    };
    vws.send(JSON.stringify(wsSpeaking));
  };

  self.stopStream = function(cb){
    console.log("Stopping Stream");
    if(self.internals.voice.ready && !self.internals.voice.pause){
      self.setSpeaking(false);
      self.internals.voice.allowPlay = false;
      self.internals.voice.pauseData = null;
      if(self.internals.voice.enc){
        self.internals.voice.enc.stdin.setEncoding('utf8');
        try{
          self.internals.voice.enc.stdin.write('q');
        }
        catch(err){
          debug("Error: Write After End Occured\n"+err);
        }
      }
      if(cb) cb();
    }
  };


  self.setStatus = function(name){
    var dataMsg = {
      "op": 3,
      "d" :{
        "idle_since": null,
        "game": {
          "name": name
        }
      }
    };
    if(ws.readyState === ws.OPEN){
      ws.send(JSON.stringify(dataMsg));
      debug("Status Succesfully Set to \""+name+"\"");
    }
    else{
      debug("Error Occured Setting Status: Gateway Connection Interuption");
    }
  };

  self.sendMessage = function(channel_id, msg, tts){
      console.log(keys.token);
      tts = tts || "false";
      req.post({
          url: "https://discordapp.com/api/channels/"+channel_id+"/messages",
          headers: {
              "Authorization": "Bot "+keys.token
          },
          form: {
              content: msg,
              tts: tts
          }
      }, function optionalCallback(err, httpResponse, body) {
          if (err) {
              return debug("Error Sending Message "+err);
          }
          debug("Message Create Sent to gateway");
      });
  };

  self.sendFile = function(channel_id, file, msg, tts){
    tts = tts || "false";
    r = req.post({
      url: "https://discordapp.com/api/channels/"+channel_id+"/messages",
      headers: {
        "Authorization": "Bot "+keys.token,
        "Content-Type": "multipart/form-data"
      }
    }, function optionalCallback(err, httpResponse, body) {
        if (err) {
          return debug("Error Sending Message with file"+err);
        }
        debug("Message Create with File Sent to gateway");
      });
    form = r.form();
    form.append('file', file, {filename: 'profile.png'})
  };

  self.joinVoice = function(channel_id, guild_id){
    //join a voice channel
    var msg = {
      "op": 4,
      "d" :{
            "guild_id": guild_id,
            "channel_id": channel_id,
            "self_mute": false,
            "self_deaf": false
          }
      };
      ws.send(JSON.stringify(msg));
      self.internals.voice.channel_id = channel_id;
  };

  self.leaveVoice = function(guild_id){
    //leave any voice channel
    var msg = {
      "op": 4,
      "d" :{
            "guild_id": guild_id,
            "channel_id": null,
            "self_mute": false,
            "self_deaf": false
          }
      };
    ws.send(JSON.stringify(msg));
    clearInterval(vhb);
    self.internals.voice = {};
    vhb = null;
    if(vws) vws.close();
  };

  //Util
  function debug(msg){
    if(options.debug){
      var d = new Date();
      var time = "["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"] ";
      console.log(time+msg);
    }
  }

  self.connect = function(){
    if(!self.connected) return init();
  };

  if(options.autorun){ //when using autorun, care for load times of modules, early events may not be sent to parent
    self.connect();
  }

  process.on('uncaughtException', function (err) {
      // Handle ECONNRESETs caused by `next` or `destroy`
      if (err.code == 'ECONNRESET') {
        self.sendMessage("169555395860234240", ":name_badge: **FATAL ERROR**\n        **Error**: A fatal error occured with code `ECONNRESET`.\n        **Message**: Skipping this song, no clue what this error means???**Stack:**\n```"+err.stack.toString()+"\n```");
        console.log('Got an ECONNRESET! This is *probably* not an error. Stacktrace:');
        self.sendMessage("169555395860234240","Fatal Error",true);
        console.log(err.stack);
      }
      else if (err.code == 'EPIPE') {
        self.sendMessage("169555395860234240", ":name_badge: **FATAL ERROR**\n        **Error**: A fatal error occured with code `EPIPE`.\n        **Message**: Skipping this song, no clue what this error means???**Stack:**\n```"+err.stack.toString()+"\n```");
        console.log('Got an EPIPE! This is *probably* not an error. Stacktrace:');
        self.sendMessage("169555395860234240","Fatal Error",true);
        console.log(err.stack);
      }else {
          // Normal error handling
          console.error(err);
          process.exit(1);
      }
  });
};

util.inherits(DiscordClient,EE); //get DiscordClient class to inherit event emitter class and act as an event emitter
module.exports = DiscordClient;
