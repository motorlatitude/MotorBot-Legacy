
class GuildCreateEvent

  constructor: (@Client, @Logger, @guild) ->
    if @Client.channels["432351112616738837"] && @guild.id == "130734377066954752"
      #first load of the KTJ guild, post restart notice
      @Client.channels["432351112616738837"].sendMessage("","embed": {
        "title": ":warning: MOTORBOT RESTARTED"
        "description": "\n \nMotorBot had to restart, please contact the system administrator if this behaviour was unexpected.\n\n*version: 0.6.0*\n*author: Lennart Hase*\n*license: MIT License Copyright (c) 2018 Lennart Hase*\n \n",
        "color": 16724787,
        "timestamp": new Date().toISOString(),
        "footer": {
          "icon_url": "https://cdn.discordapp.com/avatars/169554882674556930/eb3d8df4dc7cf9852701cf5031da0c2f.png?size=512",
          "text": "MotorBot"
        },
      })


module.exports = GuildCreateEvent