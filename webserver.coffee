morgan = require 'morgan'
express = require "express"
fs = require 'fs'
nib = require 'nib'
stylus = require 'stylus'
compression = require 'compression'
serveStatic = require 'serve-static'
bodyParser = require('body-parser')
cookieParser = require('cookie-parser')
session = require('express-session')
passport = require 'passport'
RedisStore = require('connect-redis')(session)
flash = require('connect-flash')

class WebServer

  constructor: (@app) ->

  start: () ->
    self = @
    @site = express()
    #@site.use(morgan('\[DEBUG\]\['+new Date().getDate()+"\/"+(parseInt(new Date().getMonth())+1)+"\/"+new Date().getFullYear()+' \] :remote-addr :remote-user :method :url HTTP/:http-version :status :res[content-length] - :response-time ms'))
    compile = (str, path) ->
      stylus(str).set('filename',path).set("compress",true).use(nib())
    @app.debug("Express Should Trust Proxy Connections")
    @site.set('trust proxy', 1)
    @app.debug("Setting Views Directory")
    @site.set('views', __dirname+'/views')
    @app.debug("Setting View Engine")
    @site.set('view engine', 'pug')
    @app.debug("Setting Stylus Middleware")
    @site.use(stylus.middleware({
        src: __dirname + '/static',
        compile: compile
      })
    )
    @app.debug("Setting Static File Directory Location")
    @site.use(serveStatic(__dirname + '/static'))
    @site.use(serveStatic(__dirname + '/static/img', { maxAge: 86400000 }))
    @app.debug("Setting Response Headers")
    @site.use((req, res, next) ->
      res.setHeader('Access-Control-Allow-Origin', '*')
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, PATCH, PUT')
      res.setHeader('Access-Control-Allow-Headers', 'X-Requested-With,content-type')
      res.setHeader('Access-Control-Allow-Credentials', true)
      res.setHeader('X-Cluster-Identifier', process.pid)
      next()
    )
    @app.debug("Setting Compression")
    @site.use(compression())
    @app.debug("Setting Body Parser")
    @site.use(bodyParser.json({limit: "10mb"}));
    @site.use(bodyParser.urlencoded({ extended: false, limit: "10mb"}))
    @app.debug("Setting up Cookie Parser")
    @site.use(cookieParser("9`hIi6Z89*0gMHfYqLEJGfWMCK(d9YM0C"))
    @app.debug("Setting Up Session with Redis Storage")
    @site.use(session({
      secret: '9`hIi6Z89*0gMHfgh3sdsfdwerwrefd43',
      resave: false,
      saveUninitialized: true,
      store: new RedisStore({
        host: "localhost",
        port: 6379
      })
    }))
    @app.debug("Setting Up Connect-Flash")
    @site.use(flash())
    @app.debug("Initializing Passport")
    @site.use(passport.initialize())
    @app.debug("Initializing Passport Sessions")
    @site.use(passport.session())

    @site.locals.motorbot = self.app

    #Express Routers
    @app.debug("Registering Route ./routes/playlistv2")
    @site.use("/", require('./routes/playlistv2'))
    @app.debug("Registering Route ./routes/loginflow")
    @site.use("/loginflow", require('./routes/loginflow'))
    @app.debug("Registering Route ./routes/api_routes/oauth2")
    @site.use("/api/oauth2", require('./routes/api_routes/oauth2'))
    @app.debug("Registering Route ./routes/api_routes/music")
    @site.use("/api/music", require('./routes/api_routes/music'))
    @app.debug("Registering Route ./routes/api_routes/playlist")
    @site.use("/api/playlist", require('./routes/api_routes/playlist'))
    @app.debug("Registering Route ./routes/api_routes/user")
    @site.use("/api/user", require('./routes/api_routes/user'))
    @app.debug("Registering Route ./routes/api_routes/queue")
    @site.use("/api/queue", require('./routes/api_routes/queue'))
    @app.debug("Registering Route ./routes/api_routes/motorbot")
    @site.use("/api/motorbot", require('./routes/api_routes/motorbot'))
    @app.debug("Registering Route ./routes/api_routes/browse")
    @site.use("/api/browse", require('./routes/api_routes/browse'))
    @app.debug("Registering Route ./routes/api_routes/spotify")
    @site.use("/api/spotify", require('./routes/api_routes/spotify'))
    @app.debug("Registering Route ./routes/api_routes/track")
    @site.use("/api/track", require('./routes/api_routes/track'))
    @app.debug("Registering Route ./routes/api_routes/electron")
    @site.use("/api/electron", require('./routes/api_routes/electron'))
    @app.debug("Registering Route ./routes/api_routes/search")
    @site.use("/api/search", require('./routes/api_routes/search'))
    @app.debug("Registering Route ./routes/api_routes/message_history")
    @site.use("/api/message_history", require('./routes/api_routes/message_history'))
    @app.debug("Registering Route ./routes/api_routes/twitch")
    @site.use("/twitch", require('./routes/twitch'))
    @app.debug("Registering Route ./routes/api_routes/DiscordWebsocketEvent")
    @site.use("/api/DiscordWebsocketEvent", require('./routes/api_routes/DiscordWebsocketEvent'))
    @app.debug("Registering Routes Complete")

    #redirect for when adding bot
    @site.get("/redirect", (req, res) ->
      #code = req.query.code
      guildId = req.query.guild_id
      #console.log req
      res.end(JSON.stringify({guildId: guildId, connected: true}))
    )


module.exports = WebServer
