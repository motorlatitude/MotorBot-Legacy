DiscordClient = require '../discordClient/discordClient.coffee'
chai = require 'chai'
chai.should()
chai.expect()

describe 'sanity check', ->
  it 'check sanity', ->
    (true).should.equal true

describe 'discordClient Initialisation', ->
  it 'should create a discordClient object', ->
    dc = new DiscordClient({token: "MTY5NTU0ODgyNjc0NTU2OTMw.CfAmNQ.WebsSsEexNlFWaNc2u54EP-hIX0"})
    (typeof(dc)).should.equal 'object'
    describe 'discordClient gateway connection', ->
      it 'should connect to discord gateway server', ->
        dc.on('ready', () ->
          dc.internals.connected.should.equal true
        )