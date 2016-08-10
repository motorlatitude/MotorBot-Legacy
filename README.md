[![MotorbotHeader](https://github.com/motorlatitude/MotorBot/blob/master/motorbotHeader.png?raw=true)]()


[![Github Issues](https://img.shields.io/github/issues/motorlatitude/motorbot.svg)]() &nbsp; &nbsp;
[![Build Status](https://travis-ci.org/motorlatitude/MotorBot.svg?branch=master)](https://travis-ci.org/motorlatitude/MotorBot)
[![GitHub release](https://img.shields.io/github/release/motorlatitude/motorbot.svg)]() &nbsp; &nbsp;
[![Chrome Web Store](https://img.shields.io/chrome-web-store/v/pgkdpldhnmmhpdfmmkgpnpofaaagomab.svg)]()


MotorBot is a bot for discord, built from nodeJS, using discords public API (https://discordapp.com/developers/docs/) to allow users access to a few extra commands (can be anything really, examples include league stats, dice roles, AI talks, etc.), and the voice system to allow things like music playback, souyndboard effects, etc.

# DiscordClient Wrapper
Motorbot uses a custom written wrapper for the discord API and a basic setup would look like this:

```Javascript
var dc = new DiscordClient({token: "{BOT_TOKEN}", debug: true, autorun: true});

dc.on("ready", function(msg){
  console.log("motorbot has connected");
});

dc.on("message",function((msg,channel_id,user_id,raw_data){
  console.log(user_id+" sent a message");
  if(msg == "ping"){
    dc.sendMessage(channel_id,"pong");
  }
});
```
The DiscordClient wrapper has multiple events and methods which are described in the DiscordClientDocs.md file. *Still todo*

# Commands
All commands should be preceded with a `!` followed by the name of the command, which should be further followed by a method or a parameter of the given command.
## List of Commands

### API
  Command: `!api`<br>
  Has Methods: `sid, vsid, status`<br>
  The API methods are for the developer to analyse the current status of the API Connection that the bot has established.
###### SID
  The sid method allows you to determine the last sequence identifier sent to the discord gateway server.
###### VSID
  The sid method allows you to determine the last sequence identifier sent to the discord voice server.
###### STATUS
  The status method returns the status of the current bot-to-server connection.

### OS
  Command: `!os`<br>
  Has Methods: `[uptime]`<br>
  This command lets you determine the OS on which the bot is currently running, it provides some general information.
###### UPTIME
  The Uptime method returns the time since last boot of the server on which the bot is running.

### STATUS
  Command: `!status`<br>
  Has Methods: `null`<br>
  Has Parameters: `Status Message`<br>
  Allows the user to set the status of the bot e.g. `!status with code` will mean the status of the bot will be `Playing with code`.

### RANDOM
  Command: `!random`<br>
  Has Methods: `null`<br>
  Generates a random integer between 0 and 100.

### LOLSTAT
  Command: `!lolstat`<br>
  Has Methods: `null`<br>
  Has Parameters: `[.region] Summoner Name`<br>
  Allows you to view a profile card for a summoner. This command should be used as follows: `!lolstat squírrel` will return the profile card for the summoner `squírrel` in the **EUW** region, in order to view for a different region a region parameter must be defined as follows: `!lolstat.na squírrel`. This will now return the profile card for `squírrel` in the **NA** region.

### VOICE
  Command: `!voice`<br>
  Has Methods: `join [channel_name], leave`<br>
  The voice command can be used to establish a voice connection to discord.
###### JOIN
  The join method lets the user join a voice channel, if no channel is specified the bot will default to the General Channel
###### LEAVE
  Kicks the bot out of the current voice channel.

### MUSIC
  Command: `!music`<br>
  Has Methods: `list, add <youtube_id or link>, prev, skip, play, stop`<br>
  The music method allows the user to play music in a voice channel. The music must be in the form of a youtube video and should be added using either the chrome extension or via the youtube video ID which can be found in the URL e.g. for https://www.youtube.com/watch?v=CictPbTWkBU the youtube video id is `CictPbTWkBU`<br>
  The full URL can be used as well
  **NOTE** The bot must be in a channel for the user to use these commands.
###### LIST
  Provides a link to let you see the current playlist (https://mb.lolstat.net/)
###### ADD
  Allows the user to add a song to the playlist, this command **requires** a youtube video id parameter or youtube video URL to be provided on the call of the method. The song will be added to the playlist, if no song is present in the playlist it will immediately play the newly added song.


  **Extra Note:** The google chrome extension will allow you to add a song even if the bot is not in a voice channel, to play the added song once the bot does join a voice channel, use the `play` method of the music command.
###### PREV
  Allows you to go back a song in the playlist, if a song is currently playing the method has to be called twice in quick succession . If no song is present the music will terminate.
###### SKIP
  Allows you to skip the current song and move to the next song in the playlist. If no song is present the music will terminate.
###### PLAY
  Allows the user to resume a stopped playlist or start playing the songs present in the playlist.
###### STOP
  Stops the current song and the bot will not continue to play any more songs until the `play` method is used.

### SB (Soundboard)
  Command: `!sb`<br>
  Has Methods: `null`<br>
  Has Parameters: `pog, j3, gp, sb, wonder, wsr, 1, 2, 3`<br>
  Experimental soundboard command, the parameters define which effect to play.

### TALK
  Command: `!talk`<br>
  Has Methods: `null`<br>
  Has Parameters: `<message>`<br>
  This is an **experimental** feature that uses the APIAI library to allow the bot to talk to user.
