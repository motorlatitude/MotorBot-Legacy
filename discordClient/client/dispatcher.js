// Generated by CoffeeScript 1.10.0
(function() {
  var Dispatcher, u, util, utils, voiceConnection;

  u = require('../utils.coffee');

  utils = new u();

  util = require('util');

  voiceConnection = require('../voice/voiceConnection.coffee');


  /*
   * In charge of parsing op 0 packages and turning them into relevant EventEmitter events
   */

  Dispatcher = (function() {
    function Dispatcher(discordClient, clientConnection) {
      this.discordClient = discordClient;
      this.clientConnection = clientConnection;
    }

    Dispatcher.prototype.parseDispatch = function(data) {
      this.discordClient.internals.sequence = data.s;
      switch (data.t) {
        case 'READY':
          return this.handleReady(data);
        case 'GUILD_CREATE':
          return this.handleGuildCreate(data);
        case 'MESSAGE_CREATE':
          return this.handleMessageCreate(data);
        case 'TYPING_START':
          return utils.debug("<@" + data.d.user_id + "> is typing");
        case 'PRESENCE_UPDATE':
          return this.discordClient.emit("status", data.d.user.id, data.d.status, data.d.game, data.d);
        case 'CHANNEL_UPDATE':
          return utils.debug("CHANNEL_UPDATE event caught");
        case 'VOICE_STATE_UPDATE':
          return utils.debug("VOICE_STATE_UPDATE event caught");
        case 'VOICE_SERVER_UPDATE':
          return this.handleVoiceConnection(data);
        default:
          return utils.debug("Unhandled Dispatch t: " + data.t, "warn");
      }
    };

    Dispatcher.prototype.handleReady = function(data) {
      var self;
      utils.debug("Gateway Ready, Guilds: 0 Available / " + data.d.guilds.length + " Unavailable", "info");
      this.discordClient.internals.session_id = data.d.session_id;
      this.discordClient.internals.user_id = data.d.user.id;
      self = this;
      this.clientConnection.gatewayHeartbeat = setInterval(function() {
        var hbPackage;
        hbPackage = {
          "op": 1,
          "d": self.discordClient.internals.sequence
        };
        self.discordClient.internals.gatewayPing = new Date().getTime();
        return self.discordClient.gatewayWS.send(JSON.stringify(hbPackage));
      }, this.clientConnection.HEARTBEAT_INTERVAL);
      this.discordClient.internals.connected = true;
      return this.discordClient.emit("ready", data.d);
    };

    Dispatcher.prototype.handleGuildCreate = function(data) {
      var thisServer;
      this.discordClient.internals.servers[data.d.id] = data.d;
      this.discordClient.internals.servers[data.d.id].voice = {};
      thisServer = this.discordClient.internals.servers[data.d.id];
      return utils.debug("Joined Guild: " + thisServer.name + " (" + thisServer.presences.length + " online / " + (parseInt(thisServer.member_count) - thisServer.presences.length) + " offline)", "info");
    };

    Dispatcher.prototype.handleMessageCreate = function(data) {
      return this.discordClient.emit("message", data.d.content, data.d.channel_id, data.d.author.id, data.d);
    };

    Dispatcher.prototype.handleVoiceConnection = function(data) {
      utils.debug("Joined Voice Channel", "info");
      this.discordClient.internals.servers[data.d.guild_id].voice = new voiceConnection(this.discordClient);
      return this.discordClient.internals.servers[data.d.guild_id].voice.connect(data.d);
    };

    return Dispatcher;

  })();

  module.exports = Dispatcher;

}).call(this);

//# sourceMappingURL=dispatcher.js.map