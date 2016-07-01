# MotorBot
[![PyPI](https://img.shields.io/pypi/status/Django.svg?style=flat)]() &nbsp; &nbsp;
[![GitHub release](https://img.shields.io/badge/version-0.2-brightgreen.svg)]() &nbsp; &nbsp;
[![Chrome Web Store](https://img.shields.io/chrome-web-store/v/pgkdpldhnmmhpdfmmkgpnpofaaagomab.svg)]()


MotorBot is bot built from nodeJS, using discords public API (https://discordapp.com/developers/docs/)

# Commands
All commands should be preceded with a `!` followed by the name of the command, which should be further followed by a method or a parameter of the given command.
## List of Commands

### API
  Command: `!api`<br>
  Has Methods: `sid, status`<br>
  The API methods are for the developer to analyse the current status of the API Connection that the bot has established.
###### SID
  The sid method allows you to determine the last sequence identifier sent to the discord gateway server.
###### STATUS
  The status method returns the status of the current bot-to-server connection.

### OS
  Command: `!os`<br>
  Has Methods: `[uptime]`<br>
  This command lets you determine the OS on which the bot is currently running, it provides some general information. Sample Output:
  ```Javascript
  {
    platform: "linux",
    release: "4.4.0-28-generic",
    type: "Linux",
    loadAvg: 0.03271484375,0.0283203125,0.0048828125,
    hostname: "lolstat.net",
    memory: "269MB / 1041MB",
    arch: x64,
    cpus: [
    {
      "model": "Intel(R) Xeon(R) CPU E5-2650L v3 @ 1.80GHz",
      "speed": 1799,
      "times": {
          "user": 5652800,
          "nice": 0,
          "sys": 3032000,
          "idle": 898510200,
          "irq": 0
      }
    }
  ]
  }
  ```
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

### VOICE
  Command: `!voice`<br>
  Has Methods: `join <channel_name>, leave`<br>
  The voice command can be used to establish a voice connection to discord.
###### JOIN
  The join method lets the user join a voice channel, if no channel is specified the bot will default to the General Channel
###### LEAVE
  Kicks the bot out of the current voice channel.

### MUSIC
  Command: `!music`<br>
  Has Methods: `list, add <youtube_id>, skip, resume, stop`<br>
  The music method allows the user to play music in a voice channel. The music must be in the form of a youtube video and should be added using either the chrome extension or via the youtube video ID which can be found in the URL e.g. for https://www.youtube.com/watch?v=CictPbTWkBU the youtube video id is `CictPbTWkBU`<br>
  **NOTE** The bot must be in a channel for the user to use these commands.
###### LIST
  Lists the current songs in the playlist. The songs are ordered from up next at the top to the last song to be played at the bottom.
###### ADD
  Allows the user to add a song to the playlist, this command **requires** a youtube video id parameter to be provided on the call of the method. The song will be added to the playlist, if no song is present it will immediately play the song.


  **Extra Note:** The google chrome extension will allow you to add a song even if the bot is not in a voice channel, to play the added song once the bot does join a voice channel, use the `resume` method.
###### SKIP
  Allows you to skip the current song and move to the next song in the playlist. If no song is present the music will terminate.
###### RESUME
  Allows the user to resume a stopped playlist or start playing the songs present in the playlist.
###### STOP
  Stops the current song and the bot will not continue to play any more songs until the `resume` method is used.

### TALK
  Command: `!talk`<br>
  Has Methods: `null`<br>
  Has Parameters: `<message>`<br>
  This is an **experimental** feature that uses the APIAI library to allow the bot to talk to user.
