var request = require('request');
var WebSocketClient = require('websocket').client;

var client = new WebSocketClient();

var gatewayServer = "wss://gateway.discord.gg/";
var channels = new Array();
var voiceValues = new Array();
var inVoiceChannel = false;

var botAuthorizationToken = "MTY5NTU0ODgyNjc0NTU2OTMw.CfAmNQ.WebsSsEexNlFWaNc2u54EP-hIX0";
var botId = "169554882674556930";

client.on('connectFailed', function(error){
  console.log('[!ERROR] Connection Error to Gateway: '+error.toString());
});

var s = 0; //sequence number... changes with each recieved event
client.on('connect', function(connection){
  console.log('[ CONN ] Connection Established to Gateway ('+gatewayServer+')');

  //sendAuthentication
  var msg = {
    "op": 2,
    "d" :{
            "token": botAuthorizationToken,
            "properties": {
                "$os": "linux",
                "$browser": "Chrome",
                "$device": "my_library_name",
                "$referrer": "",
                "$referring_domain": ""
            },
            "compress": false,
            "large_threshold": 250
          }
    }
  connection.send(JSON.stringify(msg));
  console.log('[C -> S] Authentication Sent To Gateway with token: '+botAuthorizationToken);

  connection.on('error', function(error){
    console.log('[!ERROR] Connection Error to Gateway: '+error.toString());
  });

  connection.on('close', function(){
      console.log('[ CONN ] Connection to Gateway ('+gatewayServer+') has closed');
      //attempt reconnect
      console.log('[ CONN ] Attempting Reconnect to Gateway ('+gatewayServer+')');
      setTimeout(function(){client.connect(gatewayServer,null);},1000);
  });

  var setupHeartBeat = function(interval){
    if(connection.connected){
      setTimeout(function(){setupHeartBeat(interval);},interval);
      connection.send(JSON.stringify({"op": 1, "d": s}));
      console.log('[C -> S] Heartbeat Sent with Sequence Identifier: '+s);
    }
  }

  var parseCommand = function(message, channel_id, id, message_id){
    if(connection.connected){
      var cmds = ["cookies                      - cookies",
                  "usrId @%user%                - determines the user id of a specified user",
                  "voice (join|leave) %channel% - join %channel% voice channel, default is general",
                  "channels                     - List all channels*"];
      if(message.match(/\.cookies/)){
        console.log("[U -> C] cookies command sent");
        var pm = new postMessage();
        pm.msg = "I also like cookies :smile:";
        pm.channel_id = channel_id;
        pm.send();
      }
      else if(message.match(/\.usrId/)){
        console.log("[U -> C] usrId command sent");
        var user = message.replace(/\.usrId\s/,"");
        var pm = new postMessage();
        pm.msg = user + " has a user id of `"+user.replace("<@","").replace(">","")+"`";
        if(user == ".usrId"){
          pm.msg = "<@"+id+"> has a user id of `"+id+"`";
        }
        pm.channel_id = channel_id;
        pm.send();
      }
      else if(message.match(/\.help/) || message.match(/\-help/)){
        console.log("[U -> C] help command sent");
        var pm = new postMessage();
        pm.msg = "```JSON\nList of available commands:\n\n"+cmds.join("\n")+"\n\n*Message limit might be exceeded (2000 char)\n```";
        pm.channel_id = channel_id;
        pm.send();
      }
      else if(message.match(/come\sat\sme(\sbro|)/) || message.match(/fight\sme(\sbro|)/)){
        console.log("[U -> C] Fight Me Icon");
        var pm = new postMessage();
        pm.msg = "(ง’̀-‘́)ง";
        pm.channel_id = channel_id;
        pm.send();
      }
      else if(message.match(/\.channels/)){
        console.log("[U -> C] List Channels Command");
        var pm = new postMessage();
        var channelList = new Array();
        for(var i=0;i<channels.length;i++){
          channelList.push({type:channels[i]["type"],name:channels[i]["name"],id:channels[i]["id"]});
        }
        pm.msg = "```JSON\n"+JSON.stringify(channelList, null, '\t')+"\n```";
        pm.channel_id = channel_id;
        pm.send();
      }
      else if(message.match(/\.status\s/)){
        var status = message.replace(/\.status\s/,"");
        var dataMsg = {
          "op": 3,
          "d" :{
            "idle_since": null,
            "game": {
              "name": status
            }
          }
        }
        connection.send(JSON.stringify(dataMsg));
        console.log('[C -> S] Set status message');
      }
      else if(message.match(/\.voice\s/)){
        var command = message.replace(/\.voice\s/,"");
        if(command.match(/join/)){
          var chnl = command.replace(/join\s/,"");
          var chnl_id = null;
          console.log(chnl);
          for(var i=0;i<channels.length;i++){
            if(chnl == channels[i]["name"] && channels[i]["type"] == "voice"){
              chnl_id = channels[i]["id"];
            }
          }
          if(chnl_id === null){
            chnl_id = "130734378656464896";
          }
          var msg = {
            "op": 4,
            "d" :{
                  "guild_id": "130734377066954752",
                  "channel_id": chnl_id, //general channel id for KTJ
                  "self_mute": false,
                  "self_deaf": false
                }
            }
            connection.send(JSON.stringify(msg));
        }
        else if(command.match(/leave/)){
          console.log("Leave Channel");
          inVoiceChannel = false;
          var msg = {
            "op": 4,
            "d" :{
                  "guild_id": "130734377066954752",
                  "channel_id": null,
                  "self_mute": false,
                  "self_deaf": false
                }
            }
            connection.send(JSON.stringify(msg));
        }
        else{
          var pm = new postMessage();
          pm.msg = "Unknown Voice Command?";
          pm.channel_id = channel_id;
          pm.send();
        }
      }
    }
  }
  connection.on('message', function(msg){
    if(msg.type === 'utf8'){
      if(JSON.parse(msg.utf8Data)){
        var data = JSON.parse(msg.utf8Data);
        s = data["s"];
        switch(data["t"]){
          case "READY":
            console.log('[S -> C] Authentication Accepted From Gateway');
            var interval = data["d"]["heartbeat_interval"];
            setTimeout(function(){setupHeartBeat(interval);},interval);
            console.log('[C -> S] Heartbeat Setup Initiated with '+interval+'ms interval');
            //set setStatus
            var dataMsg = {
              "op": 3,
              "d" :{
                "idle_since": null,
                "game": {
                  "name": "with Discord API"
                }
              }
            }
            connection.send(JSON.stringify(dataMsg));
            break;
          case "GUILD_CREATE":
            for(var i=0;i<data["d"]["channels"].length;i++){
              channels.push(data["d"]["channels"][i]);
            }
            break;
          case "MESSAGE_CREATE":
            console.log('[S -> C] MESSAGE_CREATE event recieved');
            parseCommand(data["d"]["content"],data["d"]["channel_id"],data["d"]["author"]["id"],data["d"]["id"]);
            break;
          case "VOICE_STATE_UPDATE":
            console.log("[S -> C] VOICE_STATE_UPDATE "+data["d"]["user_id"]);
            console.log(data["d"]);
            if(data["d"]["user_id"] == botId && data["d"]["channel_id"] != null){
              voiceValues["session_id"] = data["d"]["session_id"];
              voiceValues["user_id"] = data["d"]["user_id"];
              setTimeout(function(){setupNewWS();},5000);
            }
            break;
          case "VOICE_SERVER_UPDATE":
            console.log("[S -> C] VOICE_SERVER_UPDATE");
            console.log(data["d"]);
            voiceValues["endpoint"] = "wss://"+data["d"]["endpoint"].split(":")[0];
            voiceValues["guild_id"] = data["d"]["guild_id"];
            voiceValues["token"] = data["d"]["token"];
            break;
          default:
            console.log("[S -> C] Unknown / Unhandled Event Name: "+data["t"]);
            break;
        }
      }
      else{
        //unknown message format... wtf?
      }
    }
  });

});
client.connect(gatewayServer,null);

function setupNewWS(){
  console.log("setting up new websocket");
  voiceClient = new WebSocketClient();

  voiceClient.on('connectFailed', function(error){
    console.log('[!ERROR] Connection Error to Voice Endpoint ('+voiceValues["endpoint"]+'): '+error.toString());
  });

  voiceClient.on('connect', function(connection){
    console.log('[ VCON ] Connection Established to Voice Endpoint ('+voiceValues["endpoint"]+')');
    var msg = {
              "op": 0,
              "d" :{
                    "server_id": voiceValues["guild_id"],
                    "user_id": voiceValues["user_id"],
                    "session_id": voiceValues["session_id"],
                    "token": voiceValues["token"]
                    }
              }
    connection.send(JSON.stringify(msg));

    var voiceHeartbeat = function(interval){
      if(connection.connected && inVoiceChannel){
        setTimeout(function(){voiceHeartbeat(interval);},interval);
        connection.send(JSON.stringify({"op": 3, "d": null}));
        console.log('[C -> V] Heartbeat Sent To Voice Server ('+voiceValues["endpoint"]+') '+interval+'ms');
      }
    }

    connection.on('message', function(msg){
      if(msg.type === 'utf8'){
        if(JSON.parse(msg.utf8Data)){
          var data = JSON.parse(msg.utf8Data);
          var op = data["op"];
          switch(op){
            case 2:
              inVoiceChannel = true;
              console.log('[V -> C] Connected to Voice Server ('+voiceValues["endpoint"]+')');
              console.log(data["d"]);
              var interval = data["d"]["heartbeat_interval"];
              setTimeout(function(){voiceHeartbeat(interval);},interval);
              break;
            case 5:
              console.log('[V -> C] Speaking Status Update');
              break;
            default:
              console.log('[V -> C] Unknown / Unhandled Option: '+op);
              break;
          }
        }
      }
    });
  });

  voiceClient.connect(voiceValues["endpoint"],null);


}

var postMessage = function(){
    this.msg = "";
    this.channel_id = null;
    this.tts = false;
    this.id = null;

    this.send = function(){
        if(this.channel_id != null && this.channel_id != ""){ //channel-id must be defined
          var url = "https://discordapp.com/api/channels/"+this.channel_id+"/messages";
          request.post({
            url: url,
            headers: {
              "Authorization": botAuthorizationToken
            }
          }).form({content:this.msg,tts:this.tts});
          console.log('[ POST ] Message Sent To Channels Endpoint');
        }
    }
}

var editMessage = function(){
  this.message_id = null;
  this.msg = null;
  this.channel_id = null;

  this.modify = function(){
    if(this.channel_id != null && this.message_id != null){ //channel-id and message-id must be defined
      var url = "https://discordapp.com/api/channels/"+this.channel_id+"/messages/"+this.message_id;
      request({
        method: 'PATCH',
        url: url,
        headers: {
          "Authorization": botAuthorizationToken,
          "Content-Type": "application/json"
        },
        content:this.msg
      });
      console.log('[ PTCH ] Message Sent To Channels Endpoint (edit)');
    }
  }
}
