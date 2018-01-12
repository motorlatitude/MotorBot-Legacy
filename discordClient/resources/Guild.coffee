u = require('../utils.coffee')
utils = new u()
Constants = require './../constants'

class Guild

  constructor: (@client, guild) ->
    @id = guild.id
    @name = guild.name
    @icon = guild.icon
    @splash = guild.splash
    @owner_id = guild.owner_id
    #@owner = new User() TODO integrate into user class once made
    @region = guild.region # voice region, check with voice elements
    @afk_channel_id = guild.afk_channel_id
    @afk_channel = @client.channels[@afk_channel_id]
    @afk_timeout = guild.afk_timeout
    @embed_enabled = guild.embed_enabled #widget stuff
    @embed_channel_id = guild.embed_channel_id
    if @embed_channel_id
      @embed_channel = @client.channels[@embed_channel_id]
    @verification_level = guild.verification_level
    @default_message_notification = guild.default_message_notification
    @roles = guild.roles #TODO integrate into role class once made
    @emojis = guild.emojis #TODO integrate into emoji class once made
    @features = guild.features
    @mfa_level = guild.mfa_level
    #GATE CREATE FIELDS - only sent with GUILD_CREATE event so store these
    @joined_at = guild.joined_at
    @large = guild.large || false #checks if the guild is large, assume false
    @unavailable = guild.unavailable
    @member_count = guild.member_count
    @voice_states = guild.voice_states
    @members = guild.members #TODO integrate into guildmember class once made, different from user obj but contains user obj
    @channels = guild.channels #already used to create channel array @client.channels
    @presences = guild.presences

  modify: (options) ->
    if !options then new Error("No value given for Object: options")
    finalOptions = {}
    if options.name
      if typeof options.name != "String" then new Error("Expected String for option: name, got:"+typeof options.name)
      finalOptions.name = options.name
    if options.region
      if typeof options.region != "String" then new Error("Expected String for option: region, got:"+typeof options.region)
      finalOptions.region = options.region
    if options.verification_level
      if typeof options.verification_level != "Number" then new Error("Expected Number for option: verification_level, got:"+typeof options.verification_level)
      finalOptions.verification_level = options.verification_level
    if options.default_message_notification
      if typeof options.default_message_notification != "Number" then new Error("Expected Number for option: verification_level, got:"+typeof options.default_message_notification)
      finalOptions.default_message_notification = options.default_message_notification
    if options.afk_channel_id
      if typeof options.afk_channel_id != "String" then new Error("Expected String from option: afk_channel_id, got:"+typeof options.afk_channel_id)
      finalOptions.afk_channel_id = options.afk_channel_id
    if options.afk_timeout
      if typeof options.afk_timeout != "Number" then new Error("Expected Number from option: afk_timeout, got:"+typeof options.afk_timeout)
      finalOptions.afk_timeout = options.afk_channel
    if options.icon
      #should be a base64 128x128 jpeg image
      if typeof options.icon != "String" then new Error("Expected String from option: icon, got:"+typeof options.icon)
      finalOptions.icon = options.icon
    if options.owner_id
      if typeof options.owner_id != "String" then new Error("Expected String from option: owner_id, got: "+typeof options.owner_id)
      finalOptions.owner_id = options.owner_id
    if option.splash #VIP only
      #should be a base64 128x128 jpeg image
      if typeof options.splash != "String" then new Error("Expected String from option: splash, got: "+typeof options.splash)
      finalOptions.splash = options.spash
    @client.rest.methods().modifyGuild(guild_id, finalOptions)

  delete: () -> #CAUTION
    @client.rest.methods().deleteGuild(guild_id)

  getChannels: () ->
    @client.rest.methods().getChannels(guild_id)

  createChannel: (name, options) ->
    if !name then new Error("Missing parameter String: name")
    if typeof name != "String" then new Error("Expect type String for parameter name, got: "+typeof name)
    #TODO


module.exports = Guild