u = require('../utils.coffee')
utils = new u()
ws = require 'ws'

class VoiceConnection

  constructor: (discordClient) ->
    utils.debug("New Voice Connection Started")

  connect: (params) ->
    

module.exports = VoiceConnection
