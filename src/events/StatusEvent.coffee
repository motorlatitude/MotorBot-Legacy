req = require 'request'
moment = require 'moment'
keys = require './../../keys.json'

class StatusEvent

  constructor: (@App, @Client, @Logger, user_id, status, game, extra_info) ->
    self = @
    if extra_info.guild_id == "130734377066954752" #only listening for presence updates in the KTJ guild for now to avoid duplicates across multiple channels
      if game
        self.Logger.write(user_id+"'s status ("+status+") has changed; "+game.name+"("+game.type+")","notification")
      else
        self.Logger.write(user_id+"'s status ("+status+") has changed", "notification")
      d = new Date()
      time = "`["+d.getDate()+"/"+(parseInt(d.getMonth())+1)+"/"+d.getFullYear()+" "+d.toLocaleTimeString()+"]` "
      gameText = ""
      statusText = ""
      additionalString = ""
      if game
        extra_info["last_game_update"] = new Date().getTime()
        if self.App.UserStatus[user_id]
          if self.App.UserStatus[user_id].game
            if self.App.UserStatus[user_id].game.name == game.name
              extra_info["last_game_update"] = self.App.UserStatus[user_id].last_game_update
        if game.details
          additionalString += "\n`[---------------------]` *"+game.details+"*"
        if game.state
          additionalString += "\n`[---------------------]` "+game.state

      if self.App.UserStatus[user_id]
        if self.App.UserStatus[user_id].status == status
          #no status change, only game update
          if !game && self.App.UserStatus[user_id].game
            if self.App.UserStatus[user_id].game.type == 0
              #statusText = " has stopped playing **"+userStatus[user_id].game.name+"** after "+(moment.unix(userStatus[user_id].last_game_update/1000).fromNow()).replace(" ago","")+"\n"
              self.Client.channels["432351112616738837"].sendMessageWithFile("", req.get({
                url: keys.baseURL+'/api/DiscordWebsocketEvent/capture?api_key=caf07b8b-366e-44ab-9bda-623f94a9c2df',
                json: true
                body: {
                  "PresenceUpdateData": {
                    "type": "StoppedPlaying",
                    "id": user_id,
                    "avatar": self.Client.users[user_id].avatar,
                    "user": self.Client.users[user_id].username,
                    "discriminator": self.Client.users[user_id].discriminator
                    "game": self.App.UserStatus[user_id].game.name,
                    "duration": (moment.unix(self.App.UserStatus[user_id].last_game_update/1000).fromNow()).replace(" ago","")
                  }
                }
              }), "StoppedPlaying.png")
            else if self.App.UserStatus[user_id].game.type == 1
              statusText = " has stopped streaming **"+self.App.UserStatus[user_id].game.name+"** after "+(moment.unix(self.App.UserStatus[user_id].last_game_update/1000).fromNow()).replace(" ago","")+"\n"
            else if self.App.UserStatus[user_id].game.type == 2
              statusText = " has stopped listening to **"+self.App.UserStatus[user_id].game.name+"** after "+(moment.unix(self.App.UserStatus[user_id].last_game_update/1000).fromNow()).replace(" ago","")+"\n"
          if extra_info.client_status.desktop != self.App.UserStatus[user_id].client_status.desktop || extra_info.client_status.mobile != self.App.UserStatus[user_id].client_status.mobile || extra_info.client_status.web != self.App.UserStatus[user_id].client_status.web
            #status event update on an alternative client
            dev = "Desktop"
            if extra_info.client_status.desktop != self.App.UserStatus[user_id].client_status.desktop
              dev = "Desktop"
            if extra_info.client_status.mobile != self.App.UserStatus[user_id].client_status.mobile
              dev = "Mobile"
            if extra_info.client_status.web != self.App.UserStatus[user_id].client_status.web
              dev = "Web"
            self.Client.channels["432351112616738837"].sendMessageWithFile("", req.get({
              url: keys.baseURL+'/api/DiscordWebsocketEvent/capture?api_key=caf07b8b-366e-44ab-9bda-623f94a9c2df',
              json: true
              body: {
                "PresenceUpdateData": {
                  "type": "StatusChange",
                  "id": user_id,
                  "avatar": self.Client.users[user_id].avatar,
                  "user": self.Client.users[user_id].username,
                  "discriminator": self.Client.users[user_id].discriminator,
                  "last_status": self.App.UserStatus[user_id].status,
                  "last_status_time": (moment.unix(self.App.UserStatus[user_id].last_update/1000).fromNow()).replace(" ago",""),
                  "status": status,
                  "device": dev
                }
              }
            }), "PresenceUpdateData.png")
          else
            statusText = statusText.replace(/\n/gmi,"");
          extra_info["last_update"] = self.App.UserStatus[user_id].last_update
        else
          #status change
          if extra_info.client_status.desktop != self.App.UserStatus[user_id].client_status.desktop || extra_info.client_status.mobile != self.App.UserStatus[user_id].client_status.mobile || extra_info.client_status.web != self.App.UserStatus[user_id].client_status.web
            #status event update on an alternative client
            dev = "Desktop"
            if extra_info.client_status.desktop != self.App.UserStatus[user_id].client_status.desktop
              dev = "Desktop"
            if extra_info.client_status.mobile != self.App.UserStatus[user_id].client_status.mobile
              dev = "Mobile"
            if extra_info.client_status.web != self.App.UserStatus[user_id].client_status.web
              dev = "Web"
            self.Client.channels["432351112616738837"].sendMessageWithFile("", req.get({
              url: keys.baseURL+'/api/DiscordWebsocketEvent/capture?api_key=caf07b8b-366e-44ab-9bda-623f94a9c2df',
              json: true
              body: {
                "PresenceUpdateData": {
                  "type": "StatusChange",
                  "id": user_id,
                  "avatar": self.Client.users[user_id].avatar,
                  "user": self.Client.users[user_id].username,
                  "discriminator": self.Client.users[user_id].discriminator,
                  "last_status": self.App.UserStatus[user_id].status,
                  "last_status_time": (moment.unix(self.App.UserStatus[user_id].last_update/1000).fromNow()).replace(" ago",""),
                  "status": status,
                  "device": dev
                }
              }
            }), "PresenceUpdateData.png")
            statusText = ""
          ###else
            statusText = "'s status was `"+userStatus[user_id].status+"` for "+(moment.unix(userStatus[user_id].last_update/1000).fromNow()).replace(" ago","")+" and is now `"+status+"`"###
          extra_info["last_update"] = new Date().getTime()
      else
        #we don't know previous status so assume status change
        if self.Client.users[user_id]
          self.Client.channels["432351112616738837"].sendMessageWithFile("", req.get({
            url: keys.baseURL+'/api/DiscordWebsocketEvent/capture?api_key=caf07b8b-366e-44ab-9bda-623f94a9c2df',
            json: true
            body: {
              "PresenceUpdateData": {
                "type": "RegisterPresenceUpdateUser",
                "id": user_id,
                "avatar": self.Client.users[user_id].avatar,
                "user": self.Client.users[user_id].username,
                "discriminator": self.Client.users[user_id].discriminator
                "status": status
              }
            }
          }), "RegisterPresenceUpdateUser.png")
          statusText = ""
          extra_info["last_update"] = new Date().getTime()

      if game && game.type == 0
        if self.App.UserStatus[user_id]
          if self.App.UserStatus[user_id].game
            if self.App.UserStatus[user_id].game.name != game.name
              #gameText = " is playing **"+game.name+"**"
              self.Client.channels["432351112616738837"].sendMessageWithFile("", req.get({
                url: keys.baseURL+'/api/DiscordWebsocketEvent/capture?api_key=caf07b8b-366e-44ab-9bda-623f94a9c2df',
                json: true
                body: {
                  "PresenceUpdateData": {
                    "type": "Playing",
                    "id": user_id,
                    "avatar": self.Client.users[user_id].avatar,
                    "user": self.Client.users[user_id].username,
                    "discriminator": self.Client.users[user_id].discriminator
                    "game": game.name,
                    "game_state": game.state,
                    "game_details": game.details,
                    "game_icon": game.icon,
                    "game_asset_large": if game.assets then game.assets.large_image else undefined,
                    "application_id": game.application_id
                  }
                }
              }), "Playing.png")
          else
            self.Client.channels["432351112616738837"].sendMessageWithFile("", req.get({
              url: keys.baseURL+'/api/DiscordWebsocketEvent/capture?api_key=caf07b8b-366e-44ab-9bda-623f94a9c2df',
              json: true
              body: {
                "PresenceUpdateData": {
                  "type": "Playing",
                  "id": user_id,
                  "avatar": self.Client.users[user_id].avatar,
                  "user": self.Client.users[user_id].username,
                  "discriminator": self.Client.users[user_id].discriminator
                  "game": game.name,
                  "game_state": game.state,
                  "game_details": game.details,
                  "game_icon": game.icon,
                  "game_asset_large": if game.assets then game.assets.large_image else undefined,
                  "application_id": game.application_id
                }
              }
            }), "Playing.png")
        else
          self.Client.channels["432351112616738837"].sendMessageWithFile("", req.get({
            url: keys.baseURL+'/api/DiscordWebsocketEvent/capture?api_key=caf07b8b-366e-44ab-9bda-623f94a9c2df',
            json: true
            body: {
              "PresenceUpdateData": {
                "type": "Playing",
                "id": user_id,
                "avatar": self.Client.users[user_id].avatar,
                "user": self.Client.users[user_id].username,
                "discriminator": self.Client.users[user_id].discriminator
                "game": game.name,
                "game_state": game.state,
                "game_details": game.details,
                "game_icon": game.icon,
                "game_asset_large": if game.assets then game.assets.large_image else undefined,
                "application_id": game.application_id
              }
            }
          }), "Playing.png")
      else if game && game.type == 1
        gameText = " is streaming **"+game.name+"**"
      else if game && game.type == 2
        gameText = "**"+game.name+"** Presence Update Event (Play/Pause)"
      else
        gameText = "" #status change

      if game
        if self.App.UserStatus[user_id]
          if self.App.UserStatus[user_id].game
            if self.App.UserStatus[user_id].game.name == game.name && game.type == 0
              gameText = " game presence update :space_invader:"
            else if self.App.UserStatus[user_id].game.name == game.name && game.type == 2
              gameText = "**"+game.name+"** Presence Update Event (Switching)"

      someText = if(gameText != "" && statusText != "") then " and"+gameText else gameText
      if game && game.type == 2
        additionalString = ""
        if game.details
          additionalString += "\n**"+game.details+"**"
        if game.state
          additionalString += "\n*by "+game.state+"*"
        if game.assets.large_text
          additionalString += "\non "+game.assets.large_text
        #console.log game
        thumbnail_url = ""
        if game.assets
          if game.assets.large_image
            thumbnail_id = game.assets.large_image.replace("spotify:","")
            thumbnail_url = "https://i.scdn.co/image/"+thumbnail_id
        #console.log thumbnail_url
        self.Client.channels["432351112616738837"].sendMessage("","embed": {
          "title": "<:spotify:525318301367271425>  "+statusText+someText,
          "description": additionalString,
          "color": 2021216,
          "thumbnail": {
            "url": thumbnail_url
          },
          "timestamp": new Date().toISOString(),
          "footer": {
            "icon_url": "https://cdn.discordapp.com/avatars/"+user_id+"/"+self.Client.users[user_id].avatar+".png?size=512",
            "text": self.Client.users[user_id].username+"#"+self.Client.users[user_id].discriminator
          },
        })
      else
        if statusText == "" && someText == "" && additionalString == ""
          #self.client.channels["432351112616738837"].sendMessage(time+"<@"+user_id+"> is `invisible` and a status refresh event occurred")
        else
          self.Client.channels["432351112616738837"].sendMessage(time+"<@"+user_id+">"+statusText+someText+additionalString)
          #console.log(extra_info);

      self.App.UserStatus[user_id] = extra_info


module.exports = StatusEvent