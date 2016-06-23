req = require('request');
var apiai = require('apiai');
var https = require('https');
var app = apiai("ea1bdb33a83f48c795a585e44a4cdb4b");
var DiscordClient = require('./discordClient.js');
var youtubeStream = require('youtube-audio-stream')

var dc = new DiscordClient({token: "MTY5NTU0ODgyNjc0NTU2OTMw.CfAmNQ.WebsSsEexNlFWaNc2u54EP-hIX0", debug: true, autorun: true});
var stream;
dc.on("ready", function(msg){
  var d = new Date();
  var time = "["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"] ";
  console.log(time+msg.user.username+"#"+msg.user.discriminator+" has connected to the gateway server and is at your command");

  dc.setStatus("with Discord API");
});

dc.on("message", function(msg,channel_id,user_id,raw_data){
  var d = new Date();
  var time = "["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"] "
  console.log(time+"\""+msg+"\" sent by user <@"+user_id+"> in <#"+channel_id+">");
  if(msg == ".log dump"){
    console.log(time+"Grabbing relevant file");
    var url = "https://discordapp.com/api/channels/"+channel_id+"/messages"
    req.post({
      url: url,
      headers: {
        "Authorization": "MTY5NTU0ODgyNjc0NTU2OTMw.CfAmNQ.WebsSsEexNlFWaNc2u54EP-hIX0",
        "Content-Type": "multipart/form-data"
      },
      formData: {
        content: ":wrench: Developer Debug Log, shows full log of actions carried out on the server.",
        file: {
          value: fs.readFileSync(__dirname + '/debug.log', 'utf8'),
          options: {
            contentType: "application/octet-stream",
            filename: "debug.log"
          }
        }
      }
    }, function optionalCallback(err, httpResponse, body) {
        if (err) {
          return console.error(time+'Upload failed:', err);
        }
        console.log(time+'Upload successful!');
      });
  }
  else if(msg == "!api internals"){
    console.log(time+"API Command");
    var cache = [];
    var DCInternals = JSON.stringify(dc.internals, function(key, value) {
        if (typeof value === 'object' && value !== null) {
            if (cache.indexOf(value) !== -1) {
                // Circular reference found, discard key
                return;
            }
            // Store value in our collection
            cache.push(value);
        }
        return value;
    }, '\t');
    cache = null;
    var msg = ":wrench: DiscordClient Class has the current set of internals:\n\n```JSON\n"+DCInternals+"\n```";
    dc.sendMessage(channel_id,msg);
  }
  else if(msg == "!api sid"){
    console.log(time+"API Command");
    var msg = "```Javascript\nDiscordClient.prototype.internals.sequence = "+dc.internals.sequence+"\n```";
    dc.sendMessage(channel_id,msg);
  }
  else if(msg == "!api status"){
    console.log(time+"API Command");
    var msg = "All is clear, I'm current connected to Discord Server and everything seems fine :D\n\n```Javascript\nConnected to Server: \""+dc.internals.gateway+"\"\nMy ID is: "+dc.internals.user_id+"\n```";
    dc.sendMessage(channel_id,msg);
  }
  else if(msg == "!os"){
    var msg = "```Javascript\n{\n\tplatform: \""+dc.internals.os.platform()+"\",\n\trelease: "+dc.internals.os.release()+",\n\ttype: \""+dc.internals.os.type()+"\",\n\tloadAvg: "+dc.internals.os.loadavg()+",\n\thostname: \""+dc.internals.os.hostname()+"\",\n\tmemory: \""+Math.round((parseFloat(dc.internals.os.freemem()/1000000)))+"MB / "+Math.round((parseFloat(dc.internals.os.totalmem())/1000000))+"MB\",\n\tarch: "+dc.internals.os.arch()+",\n\tcpus: "+JSON.stringify(dc.internals.os.cpus(), null, '\t')+"\n}\n```";
    dc.sendMessage(channel_id,msg);
  }
  else if(msg == "!os uptime"){
    var msg = "I've been online for: "+millisecondsToStr(parseFloat(dc.internals.os.uptime())*1000);
    dc.sendMessage(channel_id,msg);
  }
  else if(msg.match(/cum\son\sme/)){
    dc.sendMessage(channel_id,"8====D- -- - (O)");
  }
  else if(msg.match(/\!status\s/)){
    var stt = msg.replace(/\.status\s/,"");
    dc.setStatus(stt);
  }
  else if(msg.match(/\!random/)){
    dc.sendMessage(channel_id,"Random Number: "+(Math.round((Math.random()*100))));
  }
  else if(msg.match(/goodnight/gmi)){
    dc.sendMessage(channel_id,":sparkles: Good Night <@"+user_id+">");
  }
  else if(msg.match(/fight\sme(\sbro|)/gmi) || msg.match(/come\sat\sme(\sbro|)/gmi)){
    dc.sendMessage(channel_id,"(ง’̀-‘́)ง");
  }
  else if(msg.match(/\!voice\s/)){
    var command = msg.replace(/\!voice\s/,"");
    var guild_id = "130734377066954752";
    if(command.match(/join/)){
      var chnl = command.replace(/join\s/,"");
      var chnl_id = null;
      console.log(chnl);
      for(var i=0;i<dc.servers[guild_id].channels.length;i++){
        if(chnl == dc.servers[guild_id].channels[i]["name"] && dc.servers[guild_id].channels[i]["type"] == "voice"){
          chnl_id = dc.servers[guild_id].channels[i]["id"];
        }
      }
      if(chnl_id === null){
        chnl = "General";
        for(var i=0;i<dc.servers[guild_id].channels.length;i++){
          if(chnl == dc.servers[guild_id].channels[i]["name"] && dc.servers[guild_id].channels[i]["type"] == "voice"){
            chnl_id = dc.servers[guild_id].channels[i]["id"];
          }
        }
      }
      dc.joinVoice(chnl_id,guild_id);
    }
    else if(command.match(/leave/)){
      dc.leaveVoice(guild_id);
    }
  }
  else if(msg.match(/^!stop speaking/)){
    dc.stopSpeaking();
  }
  else if(msg.match(/^!music\s/)){
    var videoId = msg.split(" ")[1];
    if(videoId == "stop"){
      dc.stopStream();
    }
    else{
      var requestUrl = 'http://youtube.com/watch?v=' + videoId;
      var res = youtubeStream(requestUrl);
      dc.playStream(res);

      req.get({
        url: "https://www.googleapis.com/youtube/v3/videos?id="+videoId+"&key=AIzaSyAyoWcB_yzEqESeJm-W_eC5QDcOu5R1M90&part=snippet",
        headers: {
          "Content-Type": "application/json"
        }
      }, function optionalCallback(err, httpResponse, body) {
          if (err) {
            return console.error('Error Occured Fetching Youtube Metadata');
          }
          var data = JSON.parse(body);
          var title = data.items[0].snippet.title;
          //dc.sendMessage(channel_id,"Now Playing: "+title);
          console.log("Now Playing: "+title);
          req2 = https.request({
            host: "discordapp.com",
            path: "/api/channels/"+channel_id+"/messages/195276726475948032",
            method: "PATCH",
            headers: {
              "Authorization": "MTY5NTU0ODgyNjc0NTU2OTMw.CfAmNQ.WebsSsEexNlFWaNc2u54EP-hIX0",
              "Content-Type": "application/json"
            }
          }, function(res) {
              var data = "";
              res.setEncoding('utf8')
              res.on('data', function(chunk){
                data += chunk
              });
              res.on('end', function(){
                console.log("Music Pin Updated");
                console.log(data);
              });
          });
          req2.write(JSON.stringify({content: 'Now Playing: '+title}))
          req2.on('error', function(error){
            console.log("Error Occured Grabbing The Data");
          })
          req2.end();
      });
    }
    /*req = https.request({
      host: "discordapp.com",
      path: "/api/channels/"+channel_id+"/pins/195271369116614656",
      method: "DELETE",
      headers: {
        "Authorization": "MTY5NTU0ODgyNjc0NTU2OTMw.CfAmNQ.WebsSsEexNlFWaNc2u54EP-hIX0"
      }
    }, function(res) {
        var data = "";
        res.setEncoding('utf8')
        res.on('data', function(chunk){
          data += chunk
        });
        res.on('end', function(){
          console.log("Music Pinned");
          console.log(data);
        });
    });
    req.on('error', function(error){
      console.log("Error Occured Grabbing The Data");
    })
    req.end()*/
  }
  else if(msg.match(/^!talk\s/)){
    console.log("Talk Command Issued")
    var request = app.textRequest(msg.replace(/^!talk\s/,""));
    request.on('response', function(response) {
        console.log(response);
        dc.sendMessage(channel_id,response.result.fulfillment.speech);
    });
    request.on('error', function(error) {
        console.log(error);
    });
    request.end();
  }
});

dc.on("status", function(user_id,status,game,raw_data){
  var d = new Date();
  var time = "["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"] "
  if(status == "online"){
    console.log(time+"<@"+user_id+"> is now online");
  }
  else if(status == "idle"){
    console.log(time+"<@"+user_id+"> is now idle");
  }
  else if(status == "offline"){
    console.log(time+"<@"+user_id+"> has gone offline, bye bye :(");
  }
  else{
    console.log(time+"<@"+user_id+"> has an unknown status?");
  }

  if(game != null && status == "online"){
    console.log(time+"<@"+user_id+"> is now playing "+game["name"]);
  }

});

function millisecondsToStr (milliseconds) {
    // TIP: to find current time in milliseconds, use:
    // var  current_time_milliseconds = new Date().getTime();

    function numberEnding (number) {
        return (number > 1) ? 's' : '';
    }

    var temp = Math.floor(milliseconds / 1000);
    var years = Math.floor(temp / 31536000);
    if (years) {
        return years + ' year' + numberEnding(years);
    }
    //TODO: Months! Maybe weeks?
    var days = Math.floor((temp %= 31536000) / 86400);
    if (days) {
        return days + ' day' + numberEnding(days);
    }
    var hours = Math.floor((temp %= 86400) / 3600);
    if (hours) {
        return hours + ' hour' + numberEnding(hours);
    }
    var minutes = Math.floor((temp %= 3600) / 60);
    if (minutes) {
        return minutes + ' minute' + numberEnding(minutes);
    }
    var seconds = temp % 60;
    if (seconds) {
        return seconds + ' second' + numberEnding(seconds);
    }
    return 'less than a second'; //'just now' //or other string you like;
}

var fs = require('fs');
var util = require('util');
var log_file = fs.createWriteStream(__dirname + '/debug.log', {flags : 'a'});
var log_stdout = process.stdout;

console.log = function(d) { //
  log_file.write(util.format(d) + '\n');
  log_stdout.write(util.format(d) + '\n');
};
