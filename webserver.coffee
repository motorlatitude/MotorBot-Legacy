morgan = require 'morgan'
express = require "express"
fs = require 'fs'
stylus = require 'stylus'
nib = require 'nib'
compression = require 'compression'
serveStatic = require 'serve-static'
bodyParser = require('body-parser')
cookieParser = require('cookie-parser')
session = require('express-session')
responseTime = require('response-time')
passport = require 'passport'
LocalStrategy = require('passport-local').Strategy
RedisStore = require('connect-redis')(session)
flash = require('connect-flash')

class WebServer

  constructor: (@app) ->

  start: () ->
    self = @
    @site = express()
    @site.use(morgan('dev'))
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
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, PATCH, PUT')
      res.setHeader('Access-Control-Allow-Headers', 'X-Requested-With,content-type')
      res.setHeader('Access-Control-Allow-Credentials', true)
      res.setHeader('X-Cluster-Identifier',process.pid)
      next()
    )
    @site.use(responseTime());
    @site.use(compression())
    @site.use(bodyParser.json({limit: "10mb"}));
    @site.use(bodyParser.urlencoded({ extended: false, limit: "10mb"}))
    @site.use(cookieParser("9`hIi6Z89*0gMHfgh3sdsfdwerwrefd43"))
    @site.use(session({
      secret: '9`hIi6Z89*0gMHfgh3sdsfdwerwrefd43',
      resave: false,
      saveUninitialized: true,
      store: new RedisStore({
        host: "localhost",
        port: 6379
      })
    }))
    @site.use(flash())
    @site.use(passport.initialize())
    @site.use(passport.session())

    @site.locals.motorbot = self.app

    #Express Routers
    @site.use("/", require('./routes/playlistv2'))
    @site.use("/loginflow", require('./routes/loginflow'))
    @site.use("/api/oauth2", require('./routes/api_routes/oauth2'))
    @site.use("/api/music", require('./routes/api_routes/music'))
    @site.use("/api/playlist", require('./routes/api_routes/playlist'))
    @site.use("/api/user", require('./routes/api_routes/user'))
    @site.use("/api/queue", require('./routes/api_routes/queue'))
    @site.use("/api/motorbot", require('./routes/api_routes/motorbot'))
    @site.use("/api/browse", require('./routes/api_routes/browse'))
    @site.use("/api/spotify", require('./routes/api_routes/spotify'))
    @site.use("/api/electron", require('./routes/api_routes/electron'))
    @site.use("/api/search", require('./routes/api_routes/search'))
    @site.use("/api/message_history", require('./routes/api_routes/message_history'))
    @site.use("/twitch", require('./routes/twitch'))
    @site.use("/destiny2", require('./routes/destiny2'))

    #redirect for when adding bot
    @site.get("/redirect", (req, res) ->
      #code = req.query.code
      guildId = req.query.guild_id
      #console.log req
      res.end(JSON.stringify({guildId: guildId, connected: true}))
    )

module.exports = WebServer