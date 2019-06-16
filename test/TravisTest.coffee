DiscordClient = require 'node-discord'
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
  it 'Should Load Secret Keys', ->
    require.resolve('../keys.json')

describe 'Resolve NPM Modules', ->
  it 'Should Load node-discord', ->
    require.resolve("node-discord")
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
  describe 'Running MotorBot With Tests', ->
    app = new Main()
    it 'Should Emit Event `MotorBotReady` Once Ready', ->
      app.on("MotorBotReady", () ->
        describe "Once MotorBot Is Ready", ->
          it 'Should Have Created Database Object', ->
            app.Database.constructor.name.should.equal "Db"
          it 'Should Have Created a WebSocket Connection', ->
            app.WebSocket.constructor.name.should.equal "WebSocketServer"
          it 'Should Have Created a WebServer', ->
            app.WebServer.constructor.name.should.equal "WebServer"
          it 'Should Have Created And Store the MotorBotMusic class in @Music', ->
            app.Music.constructor.name.should.equal "MotorBotMusic"
          describe 'MotorBotMusic', ->
            it 'Should create empty object: yStream', ->
              assert(app.Music.yStream, {})
            it 'Should create empty object: musicPlayers', ->
              assert(app.Music.musicPlayers, {})
            describe 'InitialisePlaylist', ->
              songQueueCollection = app.Database.collection("songQueue")
              before(() ->
                await songQueueCollection.insertOne({_id: "unit_test_track", status: "playing"})
              )
              after(() ->
                await songQueueCollection.deleteOne({_id: "unit_test_track"})
              )
              it 'Should Clear Song Queue of tracks with status "playing" and return an empty promise', ->
                app.Music.InitialisePlaylist().should.be.fulfilled

              it 'Track Status Should Be `played`', ->
                songQueueCollection.find({_id: "unit_test_track"}).toArray((err, result) ->
                  assert(err == null, "No Error Should be returned")
                  assert(result[0].status == "played", "Track Should Be Played")
                )
      )
      app.run()
    it 'Should Have Create Debugger', ->
      app.Logger.constructor.name.should.equal "Debug"
    it 'Should Have Create DiscordClient Object', ->
      app.Client.constructor.name.should.equal "DiscordClient"
    it 'Should Have Generate A MotorBot Event Listener', ->
      app.motorbotEventHandler.constructor.name.should.equal "MotorBotEventHandler"
    describe 'Main Class Methods', ->
      describe 'CreateMongoDatabaseConnection', ->
        it 'Should Return Promise With Database Object', ->
          app.CreateMongoDatabaseConnection().should.be.fulfilled
      describe 'ConnectedGuild', ->
        it 'Should return the guild_id for the supplied user_id, should be undefined if user isn\'t connected', ->
          guild_id = app.ConnectedGuild(95164972807487488)
          assert(guild_id == undefined, "Returned guild_id should be undefined as no users are connected")

describe 'MongoDatabase', ->
  describe 'Resolve MongoDatabase Class', ->
    it 'Should Load ./../src/MongoDatabase.coffee', ->
      require.resolve('./../src/MongoDatabase.coffee')
  MongoDatabase = require './../src/MongoDatabase.coffee'
  Debug = require './../src/debug/Debug.coffee'
  describe 'Constructor', ->
    it 'Should Create Class', ->
      Logger = new Debug('verbose')
      db = new MongoDatabase(Logger)
      db.constructor.name.should.equal "MongoDatabase"
  describe 'connect', ->
    Logger = new Debug('verbose')
    db = new MongoDatabase(Logger)
    it 'Should Establish Connection With Mongo on localhost:27017 and return a Promise with a database object', ->
      db.connect().should.be.fulfilled
