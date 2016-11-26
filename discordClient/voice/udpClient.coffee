u = require('../utils.coffee')
utils = new u()
fs = require 'fs'
{EventEmitter} = require 'events'
dgram = require 'dgram'
nacl = require('tweetnacl')
Opus = require 'node-opus'
async = require 'async'

class UDPClient extends EventEmitter

  constructor: (@voiceConnection) ->
    @connected = false
    @nonce = new Buffer(24);
    @nonce.fill(0);
    @conn = {}
    @opusEncoder = new Opus.OpusEncoder(48000, 2)
    @userPacketQueue = {}
    @timestampDiff = undefined
    @prevTimestamp = undefined
    @handleQueue()

  init: (@conn) ->
    #create initial collection
    @udpClient = dgram.createSocket('udp4')
    udpInitPacket = Buffer.alloc(70)
    udpInitPacket.writeUInt16BE(parseInt(@conn.ssrc), 0, 4)
    @udpClient.send(udpInitPacket, 0, udpInitPacket.length, parseInt(@conn.port), @conn.endpoint, (err, bytes) ->
      if err
        return utils.debug("Failed to establish UDP Connection","error")
      utils.debug("UDP Init message sent")
    )
    self = @
    @udpClient.on('message', (msg, rinfo) -> self.handleUDPMessage(msg, rinfo))

  handleQueue: () ->
    self = @
    #console.log self.userPacketQueue
    if self.userPacketQueue
      async.forEach(Object.keys(self.voiceConnection.users), (key, next) ->
        if self.userPacketQueue[key]
          packet = self.userPacketQueue[key].shift()
          if packet
            if !@prevTimestamp
              @prevTimestamp = parseInt(packet.timestamp)
              fs.appendFile('./user-'+key+'.pcm', packet.data, (err) ->
                if (err) then throw err
                next()
              )
            else
              if @prevTimestamp-5 >= parseInt(packet.timestamp) && @prevTimestamp+5 <= parseInt(packet.timestamp)
                fs.appendFile('./user-'+key+'.pcm', new Buffer(1920).fill(0), (err) ->
                  if (err) then throw err
                  next()
                )
              else
                fs.appendFile('./user-'+key+'.pcm', packet.data, (err) ->
                  if (err) then throw err
                  next()
                )
              @prevTimestamp = packet.timestamp
          else
            fs.appendFile('./user-'+key+'.pcm', new Buffer(1920).fill(0), (err) ->
              if (err) then throw err
              next()
            )
        else
          next()
      , (err) ->
        setTimeout(() ->
          self.handleQueue()
        , 20)
      )
    else
      setTimeout(() ->
        self.handleQueue()
      , 20)

  handleUDPMessage: (msg, rinfo) ->
    if @connected
      ssrc = msg.readUInt32BE(8).toString(10)
      sequence = msg.readUIntBE(2,2)
      timestamp = msg.readUIntBE(4,4)
      for id, user of @voiceConnection.users
        #console.log "id: "+id
        #console.log "user.ssrc:"+user.ssrc
        #console.log(user.ssrc + "==" + ssrc)
        if parseInt(user.ssrc) == parseInt(ssrc)
          #console.log "ssrc: "+ssrc
          msg.copy(@nonce, 0, 0, 12)
          #console.log "slice: "+msg.slice(12)
          #console.log "secretKey: "+@voiceConnection.secretKey
          data = nacl.secretbox.open(new Uint8Array(msg.slice(12)), new Uint8Array(@nonce), new Uint8Array(@voiceConnection.secretKey));
          data = new Buffer(data)
          output = @opusEncoder.decode(data)
          if @userPacketQueue[id]
            @userPacketQueue[id].push({sequence: sequence, timestamp: timestamp, data: output})
          else
            @userPacketQueue[id] = []
            @userPacketQueue[id].push({sequence: sequence, timestamp: timestamp, data: output})
    else
      @connected = true
      utils.debug("UDP Package Received From: "+rinfo.address+":"+rinfo.port)
      utils.debug(msg)
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

  send: (packet, x, packetLength, port, endpoint, cb) ->
    @udpClient.send(packet, x, packetLength, port, endpoint, cb)

module.exports = UDPClient