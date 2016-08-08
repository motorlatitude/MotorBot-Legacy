u = require('../utils.coffee')
utils = new u()
{EventEmitter} = require 'events'
dgram = require 'dgram'

class UDPClient extends EventEmitter

  constructor: () ->

  init: (conn) ->
    #create initial collection
    @udpClient = dgram.createSocket('udp4')
    udpInitPacket = Buffer.alloc(70)
    udpInitPacket.writeUInt16BE(parseInt(conn.ssrc), 0, 4)
    @udpClient.send(udpInitPacket, 0, udpInitPacket.length, parseInt(conn.port), conn.endpoint, (err, bytes) ->
      if err
        return utils.debug("Failed to establish UDP Connection","error")
      utils.debug("UDP Init message sent")
    )
    self = @
    @udpClient.once('message', (msg, rinfo) -> self.handleUDPMessage(msg, rinfo))

  handleUDPMessage: (msg, rinfo) ->
    utils.debug("UDP Package Received From: "+rinfo.address+":"+rinfo.port)
    buffArr = JSON.parse(JSON.stringify(msg)).data

    localIP = ""
    localPort = msg.readUIntLE(msg.length-2,2).toString(10)
    i = 0
    for char in buffArr
      if i > 4
        if char != 0
          localIP += String.fromCharCode(char)
        else
          break
      i++
    utils.debug("Local Address: "+localIP+":"+localPort)
    @emit("ready", localIP, localPort)


module.exports = UDPClient