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




