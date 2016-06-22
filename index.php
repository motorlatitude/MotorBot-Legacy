<!DOCTYPE html>
<html>
  <head>
    <script src="http://code.jquery.com/jquery-latest.min.js" type="text/javascript"></script>
    <script type="text/javascript">
      var ws = new WebSocket("wss://gateway.discord.gg/");

      ws.onopen = function (event){
        var msg = {
          "op": 2,
          "d" :{
                  "token": "MTY5NTU0ODgyNjc0NTU2OTMw.CfAmNQ.WebsSsEexNlFWaNc2u54EP-hIX0",
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
        ws.send(JSON.stringify(msg));
      }

      var last_seq = 0;

      var voiceValues = {};

      ws.onmessage = function (event) {
        console.log(event);
        var data = JSON.parse(event.data);
        last_seq = data["s"];
        console.log(data);
        if(data["t"] == "READY"){
          console.info("Ready recieved with heartbeat_interval = "+parseFloat(data["d"]["heartbeat_interval"]));
          setInterval(function(){sendHeartBeat()}, parseFloat(data["d"]["heartbeat_interval"]));
        }
        else if(data["t"] == "MESSAGE_CREATE"){
          if(data["d"]["content"].match(/\!mb/)){
            var author = data["d"]["author"]["id"];
            console.info("command !mb recieved by "+author);
            if(data["d"]["content"].match(/\!mb\sjquery/)){
              $.ajax({
                url: 'postMessage.php?channel-id='+data["d"]["channel_id"]+'&author='+author+"&op=1",
                success: function(data){
                  console.info("Submitted message");
                }
              });
            }
            else if(data["d"]["content"].match(/\!mb\slink/)){
              $.ajax({
                url: 'postMessage.php?channel-id='+data["d"]["channel_id"]+'&author='+author+"&op=4",
                success: function(data){
                  console.info("Submitted message");
                }
              });
            }
            else if(data["d"]["content"].match(/\!mb\slolstat\s/)){
              var summoner = data["d"]["content"].replace(/\!mb\slolstat\s/,"");
              $.ajax({
                url: 'postMessage.php?channel-id='+data["d"]["channel_id"]+'&author='+author+"&op=5&summoner="+summoner,
                success: function(data){
                  console.info("Submitted message");
                }
              });
            }
            else if(data["d"]["content"].match(/\!mb\sjoinVoice/)){
              var msg = {
                "op": 4,
                "d" :{
                      "guild_id": "130734377066954752",
                      "channel_id": "130734378656464896", //general channel id for KTJ
                      "self_mute": false,
                      "self_deaf": false
                    }
                }
              ws.send(JSON.stringify(msg));
            }
            else if(data["d"]["content"].match(/\!mb\sleaveVoice/)){
              var msg = {
                "op": 4,
                "d" :{
                      "guild_id": "130734377066954752",
                      "channel_id": null,
                      "self_mute": false,
                      "self_deaf": false
                    }
                }
              ws.send(JSON.stringify(msg));
            }
            else if(data["d"]["content"].match(/\!mb\s[A-Za-z0-9\-_]/)){
              $.ajax({
                url: 'postMessage.php?channel-id='+data["d"]["channel_id"]+'&author='+author+"&op=2&string="+encodeURI(data["d"]["content"].replace("!mb ","")),
                success: function(returnedData){
                  console.info("Submitted message");
                  sendStatusUpdate(data["d"]["content"].replace("!mb ",""));
                }
              });
            }
            else{
              $.ajax({
                url: 'postMessage.php?channel-id='+data["d"]["channel_id"]+'&author='+author+"&op=0",
                success: function(data){
                  console.info("Submitted message");
                }
              });
            }
          }
        }
        else if(data["t"] == "VOICE_STATE_UPDATE"){
          voiceValues["session_id"] = data["d"]["session_id"];
          voiceValues["user_id"] = data["d"]["user_id"];
        }
        else if(data["t"] == "VOICE_SERVER_UPDATE"){
          voiceValues["endpoint"] = data["d"]["endpoint"];
          voiceValues["guild_id"] = data["d"]["guild_id"];
          voiceValues["token"] = data["d"]["token"];
          setupNewWS();
        }
      }

      function setupNewWS(){
        var voiceWS = new WebSocket("wss://"+voiceValues["endpoint"]);

        voiceWS.onopen = function (event){
          var msg = {
                    "op": 0,
                    "d" :{
                          "server_id": voiceValues["guild_id"],
                          "user_id": voiceValues["user_id"],
                          "session_id": voiceValues["session_id"],
                          "token": voiceValues["token"]
                          }
                    }
          console.log(msg)
          ws.send(JSON.stringify(msg));
        }

        voiceWS.onmessage = function (event){
          console.log(event);
        }
      }

      function sendHeartBeat(){
        var msg = {
          "op": 1,
          "d" : last_seq
        }
        ws.send(JSON.stringify(msg));
      }

      function sendStatusUpdate(value){
        var msg = {
          "op": 3,
          "d" :{
            "idle_since": null,
            "game": {
              "name": value
            }
          }
        }
        ws.send(JSON.stringify(msg));
      }

      function sendMessage(msg,channel){
        console.log(msg+channel);
        var author = "169940799784615937";
        $.ajax({
          url: 'postMessage.php?channel-id='+channel+'&author='+author+"&op=3&msg="+encodeURI(msg),
          success: function(data){
            console.info("Submitted message");
          }
        });
      }
    </script>
  </head>
  <body>
      <input type="text" placeholder="game" id="game">
      <input type="button" onClick="sendStatusUpdate(document.getElementById('game').value)" value="Submit">

      <input type="text" placeholder="Chat Message" id="msg">
      <select id="channel">
          <option value="130734377066954752">meme-free</option>
          <option value="169555395860234240">api_channel</option>
      </select>
      <input type="button" onClick="sendMessage(document.getElementById('msg').value,document.getElementById('channel').value)" value="Submit">
  </body>
</html>
