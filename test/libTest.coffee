DiscordClient = require '../discordClient/discordClient.coffee'
chai = require 'chai'
chai.should()
chai.expect()

describe 'sanity check', ->
  it 'check sanity', ->
    (true).should.equal true