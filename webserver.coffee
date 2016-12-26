express = require "express"
fs = require 'fs'
https = require 'https'
stylus = require 'stylus'
nib = require 'nib'
serveStatic = require 'serve-static'

class WebServer

  constructor: (@app) ->

  start: () ->
    self = @
    @site = express()
    compile = (str, path) ->
      stylus(str).set('filename',path).use(nib())
    @site.set('views', __dirname+'/views')
    @site.set('view engine', 'pug')
    @site.use(stylus.middleware({
        src: __dirname + '/static',
        compile: compile
      })
    )
    @site.use(serveStatic(__dirname + '/static'))
    @site.use(serveStatic(__dirname + '/static/img', { maxAge: 86400000 }))
    @site.use((req, res, next) ->
      res.setHeader('Access-Control-Allow-Origin', '*')
      res.setHeader('Access-Control-Allow-Methods', 'GET')
      res.setHeader('Access-Control-Allow-Headers', 'X-Requested-With,content-type')
      res.setHeader('Access-Control-Allow-Credentials', true)
      next()
    )
    @site.locals.motorbot = self.app

    #Express Routers
    @site.use("/", require('./routes/playlistv2'))
    @site.use("/api/music", require('./routes/api_routes/music'))
    @site.use("/api/playlist", require('./routes/api_routes/playlist'))
    @site.use("/api/user", require('./routes/api_routes/user'))
    @site.use("/api/queue", require('./routes/api_routes/queue'))

    #redirect for when adding bot
    @site.get("/redirect", (req, res) ->
    #code = req.query.code
      guildId = req.query.guild_id
      #console.log req
      res.end(JSON.stringify({guildId: guildId, connected: true}))
    )

module.exports = WebServer