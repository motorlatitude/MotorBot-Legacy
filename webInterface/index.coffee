globals = require '../models/globals.coffee'
Commands = require '../clientLib/commands.coffee'
MongoClient = require('mongodb').MongoClient
fs = require 'fs'
https = require 'https'
stylus = require 'stylus'
nib = require 'nib'
serveStatic = require 'serve-static'
express = require "express"
keys = require '../keys.json'

#Express Setup
app = express()
compile = (str, path) ->
  stylus(str).set('filename',path).use(nib())
app.set('views', '../views')
app.set('view engine', 'pug')
app.use(stylus.middleware(
  {src: '../static',
  compile: compile
  }
))
app.use(serveStatic('../static'))
app.use(serveStatic('../static/img', { maxAge: 86400000 }))
app.use((req, res, next) ->
  res.setHeader('Access-Control-Allow-Origin', '*')
  res.setHeader('Access-Control-Allow-Methods', 'GET')
  res.setHeader('Access-Control-Allow-Headers', 'X-Requested-With,content-type')
  res.setHeader('Access-Control-Allow-Credentials', true)
  next()
)

#Express Routers
app.use("/", require('../routes/playlist.coffee'))
app.use("/api", require('../routes/api.coffee'))

#redirect for when adding bot
app.get("/redirect", (req, res) ->
#code = req.query.code
  guildId = req.query.guild_id
  #console.log req
  res.end(JSON.stringify({guildId: guildId, connected: true}))
)

#create DB Connection
createDBConnection = (cb) ->
  MongoClient.connect('mongodb://localhost:27017/motorbot', (err, db) ->
    if err
      globals.dc.sendMessage("169555395860234240",":name_badge: Fatal Error: I couldn't connect to the motorbot database :cry:")
      throw new Error("Failed to connect to database, exiting")
    d = new Date()
    globals.db = db
    cb()
  )

createDBConnection(()->
  console.log "Callback"
)

#create web server for web interface and google chrome extension
server = app.listen(3210)