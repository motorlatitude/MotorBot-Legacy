// Generated by CoffeeScript 1.10.0
(function() {
  var EventEmitter, UDPClient, dgram, u, utils,
    extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    hasProp = {}.hasOwnProperty;

  u = require('../utils.coffee');

  utils = new u();

  EventEmitter = require('events').EventEmitter;

  dgram = require('dgram');

  UDPClient = (function(superClass) {
    extend(UDPClient, superClass);

    function UDPClient() {}

    UDPClient.prototype.init = function(conn) {
      var self, udpInitPacket;
      this.udpClient = dgram.createSocket('udp4');
      udpInitPacket = Buffer.alloc(70);
      udpInitPacket.writeUInt16BE(parseInt(conn.ssrc), 0, 4);
      this.udpClient.send(udpInitPacket, 0, udpInitPacket.length, parseInt(conn.port), conn.endpoint, function(err, bytes) {
        if (err) {
          return utils.debug("Failed to establish UDP Connection", "error");
        }
        return utils.debug("UDP Init message sent");
      });
      self = this;
      return this.udpClient.once('message', function(msg, rinfo) {
        return self.handleUDPMessage(msg, rinfo);
      });
    };

    UDPClient.prototype.handleUDPMessage = function(msg, rinfo) {
      var buffArr, char, i, j, len, localIP, localPort;
      utils.debug("UDP Package Received From: " + rinfo.address + ":" + rinfo.port);
      buffArr = JSON.parse(JSON.stringify(msg)).data;
      localIP = "";
      localPort = msg.readUIntLE(msg.length - 2, 2).toString(10);
      i = 0;
      for (j = 0, len = buffArr.length; j < len; j++) {
        char = buffArr[j];
        if (i > 4) {
          if (char !== 0) {
            localIP += String.fromCharCode(char);
          } else {
            break;
          }
        }
        i++;
      }
      utils.debug("Local Address: " + localIP + ":" + localPort);
      return this.emit("ready", localIP, localPort);
    };

    return UDPClient;

  })(EventEmitter);

  module.exports = UDPClient;

}).call(this);

//# sourceMappingURL=udpClient.js.map
