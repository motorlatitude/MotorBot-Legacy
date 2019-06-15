DiscordClient = require '../discordClient/discordClient.coffee'
keys = require '../keys.json'
chai = require 'chai'
chaiAsPromised = require 'chai-as-promised'
chai.use(chaiAsPromised)
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
  it 'Should Load Secret Keys', ->
    require.resolve('../keys.json')

describe 'Resolve NPM Modules', ->
  it 'Should Load ws', ->
    require.resolve("ws")
  it 'Should Load mongodb', ->
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
  it 'Should Load passport', ->
    require.resolve 'passport'
  it 'Should Load passport-local', ->
    require.resolve('passport-local').Strategy

describe 'Logger', ->
  describe 'Resolve Debug Class', ->
    it 'Should Load ./../src/debug/Debug.coffee', ->
      require.resolve('./../src/debug/Debug.coffee')
  Debug = require './../src/debug/Debug.coffee'

describe 'Main', ->
  describe 'Resolve Main Class', ->
    it 'Should Load ./../src/main.coffee', ->
      require.resolve('./../src/main.coffee')
  Main = require './../src/main.coffee'
  describe 'Constructor', ->
    app = new Main()
    it 'Should Create Debugger', ->
      app.Logger.constructor.name.should.equal "Debug"
    it 'Should Create DiscordClient Object', ->
      app.Client.constructor.name.should.equal "DiscordClient"
    it 'Should Generate A MotorBot Event Listener', ->
      app.motorbotEventHandler.constructor.name.should.equal "MotorBotEventHandler"
    describe 'CreateMongoDatabaseConnection', ->
      it 'Should Return Promise With Database Object', ->
        app.CreateMongoDatabaseConnection().should.be.fulfilled
    describe 'CreateWebSocket', ->
      it 'Should Create a WebSocket Connection', ->
        app.WebSocket.constructor.name.should.equal "WebSocketServer"
    describe 'CreateWebServer', ->
      it 'Should Create a WebServer', ->
        app.WebServer.constructor.name.should.equal "WebServer"
    describe 'CreateMotorBotMusic', ->
      it 'Should Create And Store the MotorBotMusic class in @Music', ->
        app.Music.constructor.name.should.equal "MotorBotMusic"
    describe 'ConnectedGuild', ->
      it 'Should return the guild_id for the supplied user_id, should be undefined if user isn\'t connected', ->
        guild_id = app.ConnectedGuild(95164972807487488)
        assert(guild_id == undefined, "Returned guild_id should be undefined as no users are connected")


