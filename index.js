req = require('request');
var apiai = require('apiai');
var https = require('https');
var raven = require('raven');
var apiai = apiai("ea1bdb33a83f48c795a585e44a4cdb4b");
var DiscordClient = require('./discordClient.js');
var youtubeStream = require('ytdl-core');

var dc = new DiscordClient({token: "MTY5NTU0ODgyNjc0NTU2OTMw.CfAmNQ.WebsSsEexNlFWaNc2u54EP-hIX0", debug: true, autorun: true});
var stream;

//Create Server
var express = require("express");
var MongoClient = require('mongodb').MongoClient

var app = express();
app.use(express.static(__dirname + "/static"));
app.use(function (req, res, next) {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET');
    res.setHeader('Access-Control-Allow-Headers', 'X-Requested-With,content-type');
    res.setHeader('Access-Control-Allow-Credentials', true);
    next();
});

function onError(err, req, res, next) {
    res.statusCode = 500;
    res.end(res.sentry+'\n');
}

// The request handler must be the first item
app.use(raven.middleware.express.requestHandler('https://4ef8d9b35c3541688d5efcbb237a9e7b:b2773c83068047cfabc5e5a252e68505@app.getsentry.com/85790'));

var ravenClient = new raven.Client('https://4ef8d9b35c3541688d5efcbb237a9e7b:b2773c83068047cfabc5e5a252e68505@app.getsentry.com/85790',{release: '0e4fdef81448dcfa0e16ecc4433ff3997aa53572'});

app.get('/errorTest', function(req, res) {
    ravenClient.captureException("Some long error message stuff https://4ef8d9b35c3541688d5efcbb237a9e7b:b2773c83068047cfabc5e5a252e68505@app.getsentry.com/85790 things and cookies and shit",{extra: {"key": {"child-key": "child_value"},"thing":"thingValue"},level: 'info'});
    res.end("cake");
});

app.get("/", function(req, res){
  res.end();
});



// The error handler must be before any other error middleware
app.use(raven.middleware.express.errorHandler('https://4ef8d9b35c3541688d5efcbb237a9e7b:b2773c83068047cfabc5e5a252e68505@app.getsentry.com/85790'));

app.get("/redirect", function(req, res){
  var code = req.query.code;
  var guildId = req.query.guild_id;
  res.end(JSON.stringify({guildId: guildId, connected: true}));
});

app.get("/api/playlist/:videoId", function(request,res){
  console.log("Added Item to Playlist");
  var videoId = request.params.videoId || "";
  var channel_id = "169555395860234240" // api_channel otherwise we have to get the user to oAuth, bit of a pain so don't bother
  req.get({
    url: "https://www.googleapis.com/youtube/v3/videos?id="+videoId+"&key=AIzaSyAyoWcB_yzEqESeJm-W_eC5QDcOu5R1M90&part=snippet,contentDetails",
    headers: {
      "Content-Type": "application/json"
    }
  }, function optionalCallback(err, httpResponse, body) {
      if (err) {
        return console.error('Error Occured Fetching Youtube Metadata');
      }
      var data = JSON.parse(body);
      if(data.items[0]){
        console.log(videoId);
        var playlistCollection = app.locals.db.collection("playlist")
        playlistCollection.insertOne({videoId: videoId, title: data.items[0].snippet.title, duration: data.items[0].contentDetails.duration, channel_id: channel_id, timestamp: new Date().getTime(), status: 'added'}, function(err, result){
          if(err){
            dc.sendMessage(channel_id,":warning: A database error occurred adding this track...\nReport sent to sentry, please notify admin of the following error: `Databse insertion error at line 75`");
          }
          else{
            dc.sendMessage(channel_id,":notes: Added "+data.items[0].snippet.title);
            goThroughVideoList(channel_id);
          }
          res.end(JSON.stringify({added: true}));
        });
      }
      else{
        dc.sendMessage(channel_id,":warning: Youtube Error: Googleapis returned video not found for videoId ("+videoId+")");
        res.end(JSON.stringify({added: false, error: "Youtube Error"}));
      }
  });
});

var server = app.listen(3210);

createDBConnection = function(){
  MongoClient.connect('mongodb://localhost:27017/motorbot', function(err, db){
    if(err){
      dc.sendMessage("169555395860234240",":name_badge: Fatal Error: I couldn't connect to the motorbot database :cry:");
      throw new Error("Failed to connect to database, exiting");
    }
    dc.sendMessage("169555395860234240",":white_check_mark: Connected to Motorbot Database Succesfully");
    app.locals.db = db;
  });
}

dc.on("ready", function(msg){
  var d = new Date();
  var time = "["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"] ";
  console.log(time+msg.user.username+"#"+msg.user.discriminator+" has connected to the gateway server and is at your command");
  dc.sendMessage("169555395860234240",":white_check_mark: Hi, I'm now online :smiley:");
  createDBConnection()
  dc.setStatus("with Discord API");
});

dc.on("message", function(msg,channel_id,user_id,raw_data){
  var d = new Date();
  var time = "["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"] "
  console.log(time+"\""+msg+"\" sent by user <@"+user_id+"> in <#"+channel_id+">");
  if(msg == "!api sid"){
    console.log(time+"API Command");
    var msg = "```Javascript\nDiscordClient.prototype.internals.sequence = "+dc.internals.sequence+"\n```";
    dc.sendMessage(channel_id,msg);
  }
  else if(msg == "!api status"){
    console.log(time+"API Command");
    var voice = "Not Connected";
    if(dc.internals.voice.endpoint){
      voice = dc.internals.voice.endpoint;
    }
    var msg = "All is clear, I'm current connected to Discord Server and everything seems fine :smile:\n\n```Javascript\nConnected to Server: \""+dc.internals.gateway+"\"\nMy ID is: "+dc.internals.user_id+"\nConnected to Voice Server: "+voice+"\n```";
    dc.sendMessage(channel_id,msg);
  }
  else if(msg == "!os"){
    var msg = "```Javascript\n{\n\tplatform: \""+dc.internals.os.platform()+"\",\n\trelease: "+dc.internals.os.release()+",\n\ttype: \""+dc.internals.os.type()+"\",\n\tloadAvg: "+dc.internals.os.loadavg()+",\n\thostname: \""+dc.internals.os.hostname()+"\",\n\tmemory: \""+Math.round((parseFloat(dc.internals.os.freemem()/1000000)))+"MB / "+Math.round((parseFloat(dc.internals.os.totalmem())/1000000))+"MB\",\n\tarch: "+dc.internals.os.arch()+",\n\tcpus: "+JSON.stringify(dc.internals.os.cpus(), null, '\t')+"\n}\n```";
    dc.sendMessage(channel_id,msg);
  }
  else if(msg == "!os uptime"){
    var msg = "Server Uptime: "+millisecondsToStr(parseFloat(dc.internals.os.uptime())*1000);
    dc.sendMessage(channel_id,msg);
  }
  else if(msg.match(/cum\son\sme/)){
    dc.sendMessage(channel_id,"8====D- -- - (O)");
  }
  else if(msg.match(/^!status\s/)){
    var stt = msg.replace(/!status\s/,"");
    dc.setStatus(stt);
  }
  else if(msg.match(/\!random/)){
    dc.sendMessage(channel_id,"Random Number: "+(Math.round((Math.random()*100))));
  }
  else if(msg.match(/goodnight/gmi)){
    dc.sendMessage(channel_id,":sparkles: Good Night <@"+user_id+">");
  }
  else if(msg.match(/^!ban doug/gmi)){
    dc.sendMessage(channel_id,"If only I could :rolling_eyes: <@"+user_id+">");
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
  else if(msg.match(/^!music\s/)){
    if(dc.internals.voice.ready){
      var videoId = msg.split(" ")[1];
      if(videoId == "stop"){
        dc.stopStream();
      }
      else if(videoId == "add"){
        videoId = msg.split(" ")[2];
        if(videoId.indexOf('https://') > -1){
          videoId = getParameterByName("v",videoId);
        }
        req.get({
          url: "https://www.googleapis.com/youtube/v3/videos?id="+videoId+"&key=AIzaSyAyoWcB_yzEqESeJm-W_eC5QDcOu5R1M90&part=snippet,contentDetails",
          headers: {
            "Content-Type": "application/json"
          }
        }, function optionalCallback(err, httpResponse, body) {
            if (err) {
              return console.error('Error Occured Fetching Youtube Metadata');
            }
            var data = JSON.parse(body);
            if(data.items){
              if(data.items[0]){
                console.log(videoId);
                var playlistCollection = app.locals.db.collection("playlist")
                playlistCollection.insertOne({videoId: videoId, title: data.items[0].snippet.title, duration: data.items[0].contentDetails.duration, channel_id: channel_id, timestamp: new Date().getTime(), status: 'added'}, function(err, result){
                  if(err){
                    dc.sendMessage(channel_id,":warning: A database error occurred adding this track...\nReport sent to sentry, please notify admin of the following error: `Databse insertion error at line 211`");
                  }
                  else{
                    dc.sendMessage(channel_id,":notes: Added "+data.items[0].snippet.title);
                    goThroughVideoList(channel_id);
                  }
                });
              }
              else{
                dc.sendMessage(channel_id,":warning: Youtube Error: Googleapis returned video not found for videoId ("+videoId+")");
              }
            }
            else{
              dc.sendMessage(channel_id,":warning: Youtube Error: Googleapis returned video not found for videoId ("+videoId+")");
            }
        });
      }
      else if(videoId == "skip"){
        dc.stopStream();
        goThroughVideoList();
      }
      else if(videoId == "resume"){
        goThroughVideoList();
      }
      else if(videoId == "list"){
        var playlistCollection = app.locals.db.collection("playlist")
        playlistCollection.find({status: "added"}).sort({timestamp: -1}).toArray(function(err, results){
          if(err){
            dc.sendMessage(channel_id,":warning: A database error occurred whilst listing all tracks...\nReport sent to sentry, please notify admin of the following error: `playlistCollection Error at line 239`");
          }
          else{
            if(results.length > 0){
              var songNames = [];
              for(var i=0;i<results.length;i++){
                var songTitle = results[i].title
                songNames.push(songTitle)
              }
              dc.sendMessage(channel_id,"```\n"+songNames.join("\n")+"\n```");
            }
            else{
              dc.sendMessage(channel_id,"No songs are currently in the playlist :grinning:");
            }
          }
        });
      }
      else{
        dc.sendMessage(channel_id,"You need help mate :rolling_eyes:!");
      }
    }
    else{
      dc.sendMessage(channel_id,"Hmmmmm, I think you might want to join a Voice Channel first :wink:");
    }
  }
  else if(msg.match(/^!talk\s/)){
    console.log("Talk Command Issued")
    var request = apiai.textRequest(msg.replace(/^!talk\s/,""));
    request.on('response', function(response) {
        console.log(response);
        dc.sendMessage(channel_id,response.result.fulfillment.speech);
    });
    request.on('error', function(error) {
        console.log(error);
    });
    request.end();
  }
  else if(msg.match(/^!/)){
    dc.sendMessage(channel_id,"I don't know what you want :confused:\nPlease consult the documenation at https://github.com/motorlatitude/MotorBot");
  }
});

function goThroughVideoList(){
  if(dc.internals.voice.ready){
    var playlistCollection = app.locals.db.collection("playlist")
    playlistCollection.find({status: "added"}).sort({timestamp: -1}).toArray(function(err, results){
      if(results[0]){
        var videoId = results[0].videoId;
        var channel_id = results[0].channel_id;
        var title = results[0].title;
        var trackId = results[0]._id;
        if(videoId && !dc.internals.voice.allowPlay){
          playlistCollection.updateOne({'_id': trackId},{'$set':{'status':'played'}},function(){
            console.log("Track Status Changed");
          });
          var requestUrl = 'http://youtube.com/watch?v=' + videoId;
          var yStream = youtubeStream(requestUrl,{quality: 'lowest', filter: 'audioonly'});
          yStream.on("error", function(e){
            console.log("Error Occured Loading Youtube Video");
          });
          dc.playStream(yStream);
          var dur = results[0].duration.replace("PT","").split("M")[0]+":"+results[0].duration.replace("PT","").split("M")[1].replace("S","");
          dc.sendMessage(channel_id,":play_pause: Now Playing: "+title+" ("+dur+")");
          console.log("Now Playing: "+title);
        }
      }
    });
  }
  else{
    dc.sendMessage("169555395860234240","Hmmmmm, I think you might want to join a Voice Channel first :wink:");
  }
}

dc.on("songDone", function(){
  console.log("Song Done");
  goThroughVideoList();
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

function getParameterByName(name, url) {
    if (!url) url = window.location.href;
    name = name.replace(/[\[\]]/g, "\\$&");
    var regex = new RegExp("[?&]" + name + "(=([^&#]*)|&|#|$)"),
        results = regex.exec(url);
    if (!results) return null;
    if (!results[2]) return '';
    return decodeURIComponent(results[2].replace(/\+/g, " "));
}
