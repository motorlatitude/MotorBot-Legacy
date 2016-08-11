// Generated by CoffeeScript 1.10.0
(function() {
  var Commands, VoiceCommands, apiai, globals;

  globals = require('../models/globals.coffee');

  VoiceCommands = require('./voiceCommands.coffee');

  apiai = require('apiai');

  apiai = apiai("ea1bdb33a83f48c795a585e44a4cdb4b");

  Commands = (function() {
    function Commands(channelId) {
      this.channelId = channelId != null ? channelId : "169555395860234240";
      return true;
    }

    Commands.prototype.parseMessageForCommand = function(msg, channel_id, user_id) {
      var command, guild_id, output_msg, region, request, stt, summoner, vc, voice;
      if (channel_id == null) {
        channel_id = this.channelId;
      }
      if (user_id == null) {
        user_id = "";
      }
      if (msg === "!api sid") {
        output_msg = "\`\`\`Javascript\nDiscordClient.prototype.internals.sequence = " + globals.dc.internals.sequence + "\n\`\`\`";
        return globals.dc.sendMessage(channel_id, output_msg);
      } else if (msg.match(/cookies/gmi)) {
        output_msg = "**Cookies?** I love cookies :cookie:";
        return globals.dc.sendMessage(channel_id, output_msg);
      } else if (msg.match(/^(!(initiate\s|)self(\s|)destruct(\ssequence|)|!kill(\s|)me)/gmi)) {
        output_msg = ":cold_sweat: No pleeeaaassssseee, I have children :cry: https://pbs.twimg.com/media/Cefcn6zW8AA09mQ.jpg";
        return globals.dc.sendMessage(channel_id, output_msg);
      } else if (msg === "!api vsid") {
        output_msg = "\`\`\`Javascript\nDiscordClient.prototype.internals.voice.sequence = " + globals.dc.internals.voice.sequence + "\n\`\`\`";
        return globals.dc.sendMessage(channel_id, output_msg);
      } else if (msg === "!api ssrc") {
        output_msg = "\`\`\`Javascript\nDiscordClient.prototype.internals.voice.ssrc = " + globals.dc.internals.voice.ssrc + "\n\`\`\`";
        return globals.dc.sendMessage(channel_id, output_msg);
      } else if (msg === "!api status") {
        voice = "Not Connected";
        if (globals.dc.internals.voice.endpoint) {
          voice = globals.dc.internals.voice.endpoint;
        }
        output_msg = "All is clear, I'm current connected to Discord Server and everything seems fine :smile:\n\n\`\`\`Javascript\nConnected to Server: \"" + globals.dc.internals.gateway + "\"\nMy ID is: " + globals.dc.internals.user_id + "\nConnected to Voice Server: " + voice + "\n\`\`\`";
        return globals.dc.sendMessage(channel_id, output_msg);
      } else if (msg === "!os") {
        output_msg = "\`\`\`Javascript\n{\n\tplatform: \"" + globals.dc.internals.os.platform() + "\",\n\trelease: " + globals.dc.internals.os.release() + ",\n\ttype: \"" + globals.dc.internals.os.type() + "\",\n\tloadAvg: " + globals.dc.internals.os.loadavg() + ",\n\thostname: \"" + globals.dc.internals.os.hostname() + "\",\n\tmemory: \"" + Math.round(parseFloat(globals.dc.internals.os.freemem() / 1000000)) + "MB / " + Math.round(parseFloat(globals.dc.internals.os.totalmem()) / 1000000) + "MB\",\n\tarch: " + globals.dc.internals.os.arch() + ",\n\tcpus: " + JSON.stringify(globals.dc.internals.os.cpus(), null, '\t') + "\n}\n\`\`\`";
        return globals.dc.sendMessage(channel_id, output_msg);
      } else if (msg === "!os uptime") {
        output_msg = "Server Uptime: " + millisecondsToStr(parseFloat(globals.dc.internals.os.uptime()) * 1000);
        return globals.dc.sendMessage(channel_id, output_msg);
      } else if (msg.match(/cum\son\sme/)) {
        return globals.dc.sendMessage(channel_id, "8====D- -- - (O)");
      } else if (msg.match(/^!status\s/)) {
        stt = msg.replace(/!status\s/, "");
        return globals.dc.setStatus(stt);
      } else if (msg.match(/\!random/)) {
        return globals.dc.sendMessage(channel_id, "Random Number: " + (Math.round(Math.random() * 100)));
      } else if (msg.match(/goodnight/gmi)) {
        return globals.dc.sendMessage(channel_id, ":sparkles: Good Night <@" + user_id + ">");
      } else if (msg.match(/heads\sor\stails(\?|)/gmi)) {
        if (Math.random() >= 0.5) {
          return globals.dc.sendMessage(channel_id, ":one: Heads <@" + user_id + ">");
        } else {
          return globals.dc.sendMessage(channel_id, ":zero: Tails <@" + user_id + ">");
        }
      } else if (msg.match(/^!ban doug/gmi)) {
        return globals.dc.sendMessage(channel_id, "If only I could :rolling_eyes: <@" + user_id + ">");
      } else if (msg.match(/fight\sme(\sbro|)/gmi) || msg.match(/come\sat\sme(\sbro|)/gmi)) {
        return globals.dc.sendMessage(channel_id, "(ง’̀-‘́)ง");
      } else if (msg.match(/^!help/gmi)) {
        return globals.dc.sendMessage(channel_id, "<@" + user_id + "> Check this out: https://github.com/motorlatitude/MotorBot/blob/master/README.md");
      } else if (msg.match(/^!lolstat(\s|\.euw|\.na|\.br|\.eune|\.kr|\.lan|\.las|\.oce|\.ru|\.tr|\.jp)/gmi)) {
        region = "euw";
        if (msg.replace(/^!lolstat/gmi, "").indexOf(".") > -1) {
          region = msg.replace(/^!lolstat/gmi, "").split(".")[1].split(/\s/gmi)[0];
        }
        summoner = encodeURI(msg.replace(/^!lolstat(\s|\.euw|\.na|\.br|\.eune|\.kr|\.lan|\.las|\.oce|\.ru|\.tr|\.jp)/gmi, "").replace(/\s/gmi, "").toLowerCase());
        return globals.dc.sendFile(channel_id, req('https://api.lolstat.net/discord/profile/' + summoner + '/' + region), "", false);
      } else if (msg.match(/\!voice\s/)) {
        command = msg.replace(/\!voice\s/, "");
        guild_id = "130734377066954752";
        vc = new VoiceCommands();
        return vc.parseVoiceCommand(command, guild_id);
      } else if (msg.match(/^!music\s/)) {
        if (globals.dc.internals.voice.ready) {
          vc = new VoiceCommands();
          command = msg.split(" ")[1];
          return vc.parseMusicCommand(msg, command, user_id);
        } else {
          return globals.dc.sendMessage(channel_id, "Hmmmmm, I think you might want to join a Voice Channel first :wink:");
        }
      } else if (msg.match(/^!volume\s/)) {
        if (globals.dc.internals.voice.ready) {
          if (user_id === "95164972807487488") {
            return globals.dc.internals.voice.volume = parseFloat(msg.split(/\s/)[1]);
          } else {
            return globals.dc.sendMessage("169555395860234240", ":rotating_light: Sorry, you're not authorised for this command");
          }
        } else {
          return globals.dc.sendMessage("169555395860234240", "Hmmmmm, I think you might want to join a Voice Channel first :wink:");
        }
      } else if (msg.match(/^!sb\spog/)) {
        if (globals.dc.internals.voice.ready) {
          globals.dc.stopStream();
          globals.songDone(false);
          return setTimeout(function() {
            return globals.dc.playStream('/var/www/motorbot/soundboard/play of the game.mp3', {
              volume: 3.0
            });
          }, 1000);
        } else {
          return globals.dc.sendMessage("169555395860234240", "Hmmmmm, I think you might want to join a Voice Channel first :wink:");
        }
      } else if (msg.match(/^!sb\swonder/)) {
        if (globals.dc.internals.voice.ready) {
          globals.dc.stopStream();
          globals.songDone(false);
          return setTimeout(function() {
            return globals.dc.playStream('/var/www/motorbot/soundboard/wonder.mp3', {
              volume: 3.0
            });
          }, 1000);
        } else {
          return globals.dc.sendMessage("169555395860234240", "Hmmmmm, I think you might want to join a Voice Channel first :wink:");
        }
      } else if (msg.match(/^!sb\skled/)) {
        if (globals.dc.internals.voice.ready) {
          globals.dc.stopStream();
          globals.songDone(false);
          return setTimeout(function() {
            return globals.dc.playStream('/var/www/motorbot/soundboard/Kled.mp3', {
              volume: 2.0
            });
          }, 1000);
        } else {
          return globals.dc.sendMessage("169555395860234240", "Hmmmmm, I think you might want to join a Voice Channel first :wink:");
        }
      } else if (msg.match(/^!sb\s1/)) {
        if (globals.dc.internals.voice.ready) {
          globals.dc.stopStream();
          globals.songDone(false);
          return setTimeout(function() {
            return globals.dc.playStream('/var/www/motorbot/soundboard/1.mp3', {
              volume: 3.0
            });
          }, 1000);
        } else {
          return globals.dc.sendMessage("169555395860234240", "Hmmmmm, I think you might want to join a Voice Channel first :wink:");
        }
      } else if (msg.match(/^!sb\s2/)) {
        if (globals.dc.internals.voice.ready) {
          globals.dc.stopStream();
          globals.songDone(false);
          return setTimeout(function() {
            return globals.dc.playStream('/var/www/motorbot/soundboard/2.mp3', {
              volume: 3.0
            });
          }, 1000);
        } else {
          return globals.dc.sendMessage("169555395860234240", "Hmmmmm, I think you might want to join a Voice Channel first :wink:");
        }
      } else if (msg.match(/^!sb\s3/)) {
        if (globals.dc.internals.voice.ready) {
          globals.dc.stopStream();
          globals.songDone();
          return setTimeout(function() {
            return globals.dc.playStream('/var/www/motorbot/soundboard/3.mp3', {
              volume: 3.0
            });
          }, 1000);
        } else {
          return globals.dc.sendMessage("169555395860234240", "Hmmmmm, I think you might want to join a Voice Channel first :wink:");
        }
      } else if (msg.match(/^!sb\sgp/)) {
        if (globals.dc.internals.voice.ready) {
          globals.dc.stopStream();
          globals.songDone(false);
          return setTimeout(function() {
            return globals.dc.playStream('/var/www/motorbot/soundboard/gp.mp3', {
              volume: 3.0
            });
          }, 1000);
        } else {
          return globals.dc.sendMessage("169555395860234240", "Hmmmmm, I think you might want to join a Voice Channel first :wink:");
        }
      } else if (msg.match(/^!sb\sj3/)) {
        if (globals.dc.internals.voice.ready) {
          globals.dc.stopStream();
          globals.songDone();
          return setTimeout(function() {
            return globals.dc.playStream('/var/www/motorbot/soundboard/justice 3.mp3', {
              volume: 3.0
            });
          }, 1000);
        } else {
          return globals.dc.sendMessage("169555395860234240", "Hmmmmm, I think you might want to join a Voice Channel first :wink:");
        }
      } else if (msg.match(/^!sb\ssb/)) {
        if (globals.dc.internals.voice.ready) {
          globals.dc.stopStream();
          globals.songDone(false);
          return setTimeout(function() {
            return globals.dc.playStream('/var/www/motorbot/soundboard/speed boost.mp3', {
              volume: 3.0
            });
          }, 1000);
        } else {
          return globals.dc.sendMessage("169555395860234240", "Hmmmmm, I think you might want to join a Voice Channel first :wink:");
        }
      } else if (msg.match(/^!sb\swsr/)) {
        if (globals.dc.internals.voice.ready) {
          globals.dc.stopStream();
          globals.songDone();
          return setTimeout(function() {
            return globals.dc.playStream('/var/www/motorbot/soundboard/wsr.mp3', {
              volume: 1.0
            });
          }, 1000);
        } else {
          return globals.dc.sendMessage("169555395860234240", "Hmmmmm, I think you might want to join a Voice Channel first :wink:");
        }
      } else if (msg.match(/^!sb\saffirmative/)) {
        if (globals.dc.internals.voice.ready) {
          globals.dc.stopStream();
          globals.songDone(false);
          return setTimeout(function() {
            return globals.dc.playStream('/var/www/motorbot/soundboard/affirmative.mp3', {
              volume: 3.0
            });
          }, 1000);
        } else {
          return globals.dc.sendMessage("169555395860234240", "Hmmmmm, I think you might want to join a Voice Channel first :wink:");
        }
      } else if (msg.match(/^!talk\s/)) {
        console.log("Talk Command Issued");
        request = apiai.textRequest(msg.replace(/^!talk\s/, ""));
        request.on('response', function(response) {
          console.log(response);
          return globals.dc.sendMessage(channel_id, response.result.fulfillment.speech);
        });
        request.on('error', function(error) {
          globals.raven.captureException(err, {
            level: 'error',
            tags: [
              {
                instigator: 'APIAI'
              }
            ]
          });
          return console.log(error);
        });
        return request.end();
      } else if (msg.match(/^!/)) {
        return globals.dc.sendMessage(channel_id, "I don't know what you want :cry:");
      }
    };

    return Commands;

  })();

  module.exports = Commands;

}).call(this);

//# sourceMappingURL=commands.js.map