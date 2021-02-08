
class MotorBotSoundboard

  constructor: (@App, @Logger) ->
    @soundboards = {}

  play: (guild_id, filepath, volume = 1) ->
    self = @
    if !self.soundboards[guild_id]
      self.App.Client.voiceConnections[guild_id].playFromFile(filepath).then((audioPlayer) ->
        self.soundboards[guild_id] = audioPlayer
        self.App.org_volume = 0.5 #set default
        self.soundboards[guild_id].on('streamDone', () ->
          self.Logger.write("StreamDone Received")
          delete self.soundboards[guild_id]
          if self.App.Music.musicPlayers[guild_id]
            self.App.Music.musicPlayers[guild_id].setVolume(self.app.org_volume) #set back to original volume of music
            self.App.Music.musicPlayers[guild_id].play()
        )
        self.soundboards[guild_id].on('ready', () ->
          if self.App.Music.musicPlayers[guild_id]
            self.App.org_volume = self.app.musicPlayers[guild_id].getVolume()
            self.App.musicPlayers[guild_id].pause()
          else
            self.soundboards[guild_id].setVolume(volume)
            self.soundboards[guild_id].play()
        )
        self.App.Music.musicPlayers[guild_id].on("paused", () ->
          if self.soundboards[guild_id]
            self.soundboards[guild_id].setVolume(volume)
            self.soundboards[guild_id].play()
        )
      )
    else
      self.Logger.write("Soundboard already playing")

  stop: (guild_id) ->
    if @soundboards[guild_id]
      @soundboards[guild_id].stop()
      delete self.soundboards[guild_id]

module.exports = MotorBotSoundboard