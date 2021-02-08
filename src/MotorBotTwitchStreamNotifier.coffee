req = require 'request'
keys = require './../keys.json'

class MotorBotTwitchStreamNotifier

  constructor: (@App, @Logger, @twitch_key) ->


  RegisterListener: (user_id) ->
    #Subscribe to Twitch WebHook Services
    #TODO expires after 10 days unless bot is restarted, make sure to resubscribe before then
    self = @
    req.post({
      url: "https://api.twitch.tv/helix/webhooks/hub?hub.mode=subscribe&hub.topic=https://api.twitch.tv/helix/streams?user_id="+user_id+"&hub.callback="+keys.baseUrl+"/twitch/callback&hub.lease_seconds=864000&hub.secret=hexweaver"
      headers: {
        "Client-ID": self.twitch_key
      },
      json: true
    }, (error, httpResponse, body) ->
      self.Logger.write("Twitch WebHook Subscription Response Code: "+httpResponse.statusCode+" For User: "+user_id, "debug", true)
      if error
        self.Logger.write("Twitch WebHook Subscription For User: "+user_id, "debug", false)
        console.log error
    )

module.exports = MotorBotTwitchStreamNotifier