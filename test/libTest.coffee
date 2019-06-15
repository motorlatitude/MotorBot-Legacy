DiscordClient = require '../discordClient/discordClient.coffee'
keys = require '../keys.json'
chai = require 'chai'
chai.should()
expect = chai.expect
assert = chai.assert

process.env.NODE_ENV = "test"

describe 'sanity check', ->
  it 'check sanity', ->
    (true).should.equal true

describe 'Load Custom Modules', ->
  it 'Should Load DiscordClient Library', ->
    require.resolve('../discordClient/discordClient')
  it 'Should Load MotorBot Webserver', ->
    require.resolve('../webserver')
  it 'Should Load MotorBot Event Handler', ->
    require.resolve('../motorbotEventHandler')
  it 'Should Load Secret Keys', ->
    require.resolve('../keys.json')

describe 'Load NPM Modules', ->
  it 'Should Load WebSocket (ws)', ->
    require.resolve("ws")
  it 'Should Load MongoDB', ->
    require.resolve('mongodb')
  it 'Should Load ytdl-core', ->
    require.resolve('ytdl-core')
  it 'Should Load request', ->
    require.resolve('request')
  it 'Should Load cuid', ->
    require.resolve('cuid')
  it 'Should Load readline', ->
    require.resolve('readline')
  it 'Should Load cli-table', ->
    require.resolve('cli-table')
  it 'Should Load string-argv', ->
    require.resolve('string-argv')
  it 'Should Load asciify-image', ->
    require.resolve('asciify-image')
  describe "Express Web Server Used Modules", ->
    it 'Should Load morgan', ->
      require.resolve 'morgan'
    it 'Should Load express', ->
      require.resolve "express"
    it 'Should Load stylus', ->
      require.resolve 'stylus'
    it 'Should Load nib', ->
      require.resolve 'nib'
    it 'Should Load compression', ->
      require.resolve 'compression'
    it 'Should Load serve-static', ->
      require.resolve 'serve-static'
    it 'Should Load body-parser', ->
      require.resolve 'body-parser'
    it 'Should Load cookie-parser', ->
      require.resolve 'cookie-parser'
    it 'Should Load express-session', ->
      require.resolve 'express-session'
    it 'Should Load response-time', ->
      require.resolve 'response-time'
    it 'Should Load redis', ->
      require.resolve 'connect-redis'
    it 'Should Load connect-flash', ->
      require.resolve 'connect-flash'
    describe "Should Load PassportJS Components", ->
      it 'Should Load passport', ->
        require.resolve 'passport'
      it 'Should Load passport-local', ->
        require.resolve('passport-local').Strategy

describe 'DiscordClient Object', ->
  client = new DiscordClient({token: keys.token})
  it 'Should Create a DiscordClient Object', ->
    client.constructor.name.should.equal "DiscordClient"
  describe "Awaiting Events", ->
    it "Should Receive Valid Gateway", (done) ->
      client.on("gateway_found", (data) ->
        console.log "\tGateway Found Event Received"
        assert(typeof data == "string", "Discord Gateway URL should be of type string")
        console.log "\tDiscord Gateway: "+data
        done()
      )
    it "Should Receive Valid Ready Event", (done) ->
      client.on("ready", (data) ->
        console.log "\tReady Event Received"
        assert(data.v == 6, "Discord Gateway Protocol version should equal 6")
        console.log "\tDiscord Gateway Protocol Version 6"
        expect(client.internals.gateway).to.be.a("string")
        assert(client.connected == true, "Client Connected Public Var Should Be Set To True")
        done()
      )
  it "Should Determine Gateway Address and Connect", () ->
    client.connect()
    expect(client.internals).to.be.a("object")
  it "Should Create Empty Public Variables", () ->
    assert(typeof client.internals == "object", "DiscordClient Internals Created")
    assert(typeof client.internals.voice == "object", "DiscordClient Voice Internals Created")
    assert(client.internals.sequence == 0, "DiscordClient Sequence Is Starting At 0")
    assert(typeof client.channels == "object", "DiscordClient Channels Created")
    assert(typeof client.guilds == "object", "DiscordClient Guilds Created")
    assert(typeof client.users == "object", "DiscordClient Users Created")
    assert(typeof client.voiceHandlers == "object", "DiscordClient voiceHandlers Created")
    assert(typeof client.voiceConnections == "object", "DiscordClient voiceConnections Created")