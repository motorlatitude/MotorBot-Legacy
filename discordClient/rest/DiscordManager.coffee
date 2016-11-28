u = require('../utils.coffee')
utils = new u()
DiscordMethods = require './DiscordMethods'
Requester = require './Requester'

class DiscordManager

  constructor: () ->
    @requester = new Requester()

  methods: () ->
    return new DiscordMethods(@requester)

module.exports = DiscordManager