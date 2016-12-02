u = require('../utils.coffee')
utils = new u()
DiscordMethods = require './DiscordMethods'
Requester = require './Requester'

class DiscordManager

  constructor: (@client) ->
    @requester = new Requester()

  methods: () ->
    return new DiscordMethods(@client, @requester)

module.exports = DiscordManager