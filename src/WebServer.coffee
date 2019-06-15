
fs = require 'fs'

morgan = require 'morgan'
express = require "express"
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

  constructor: (@app, @Logger) ->

  start: () ->
    self = @
    @site = express()
    #@site.use(morgan('\[DEBUG\]\['+new Date().getDate()+"\/"+(parseInt(new Date().getMonth())+1)+"\/"+new Date().getFullYear()+' \] :remote-addr :remote-user :method :url HTTP/:http-version :status :res[content-length] - :response-time ms'))
    compile = (str, path) ->
      stylus(str).set('filename',path).set("compress",true).use(nib())
    @Logger.write("Express Should Trust Proxy Connections")
    @site.set('trust proxy', 1)
    @Logger.write("Setting Views Directory")
    @site.set('views', __dirname+'/web/views')
    @Logger.write("Setting View Engine")
    @site.set('view engine', 'pug')
    @Logger.write("Setting Stylus Middleware")
    @Logger.write(__dirname)
    @site.use(stylus.middleware({
        src: __dirname + '/web/static',
        compile: compile
      })
    )
    @Logger.write("Setting Static File Directory Location")
    @site.use(serveStatic(__dirname + '/web/static'))
    @site.use(serveStatic(__dirname + '/web/static/img', { maxAge: 86400000 }))
    @Logger.write("Setting Response Headers")
    @site.use((req, res, next) ->
      res.setHeader('Access-Control-Allow-Origin', '*')
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, PATCH, PUT')
      res.setHeader('Access-Control-Allow-Headers', 'X-Requested-With,content-type')
      res.setHeader('Access-Control-Allow-Credentials', true)
      res.setHeader('X-Cluster-Identifier', process.pid)
      next()
    )
    @Logger.write("Setting Compression")
    @site.use(compression())
    @Logger.write("Setting Body Parser")
    @site.use(bodyParser.json({limit: "10mb"}));
    @site.use(bodyParser.urlencoded({ extended: false, limit: "10mb"}))
    @Logger.write("Setting up Cookie Parser")
    @site.use(cookieParser("9`hIi6Z89*0gMHfYqLEJGfWMCK(d9YM0C"))
    @Logger.write("Setting Up Session with Redis Storage")
    @site.use(session({
      secret: '9`hIi6Z89*0gMHfgh3sdsfdwerwrefd43',
      resave: false,
      saveUninitialized: true,
      store: new RedisStore({
        host: "localhost",
        port: 6379
      })
    }))
    @Logger.write("Setting Up Connect-Flash")
    @site.use(flash())
    @Logger.write("Initializing Passport")
    @site.use(passport.initialize())
    @Logger.write("Initializing Passport Sessions")
    @site.use(passport.session())

    @site.locals.motorbot = self.app

    #Express Routers
    @Logger.write("Registering Route ./web/routes/playlistv2")
    @site.use("/", require('./web/routes/playlistv2'))
    @Logger.write("Registering Route ./web/routes/loginflow")
    @site.use("/loginflow", require('./web/routes/loginflow'))
    @Logger.write("Registering Route ./web/routes/api_routes/oauth2")
    @site.use("/api/oauth2", require('./web/routes/api_routes/oauth2'))
    @Logger.write("Registering Route ./web/routes/api_routes/music")
    @site.use("/api/music", require('./web/routes/api_routes/music'))
    @Logger.write("Registering Route ./web/routes/api_routes/playlist")
    @site.use("/api/playlist", require('./web/routes/api_routes/playlist'))
    @Logger.write("Registering Route ./web/routes/api_routes/user")
    @site.use("/api/user", require('./web/routes/api_routes/user'))
    @Logger.write("Registering Route ./web/routes/api_routes/queue")
    @site.use("/api/queue", require('./web/routes/api_routes/queue'))
    @Logger.write("Registering Route ./web/routes/api_routes/motorbot")
    @site.use("/api/motorbot", require('./web/routes/api_routes/motorbot'))
    @Logger.write("Registering Route ./web/routes/api_routes/browse")
    @site.use("/api/browse", require('./web/routes/api_routes/browse'))
    @Logger.write("Registering Route ./web/routes/api_routes/spotify")
    @site.use("/api/spotify", require('./web/routes/api_routes/spotify'))
    @Logger.write("Registering Route ./web/routes/api_routes/track")
    @site.use("/api/track", require('./web/routes/api_routes/track'))
    @Logger.write("Registering Route ./web/routes/api_routes/electron")
    @site.use("/api/electron", require('./web/routes/api_routes/electron'))
    @Logger.write("Registering Route ./web/routes/api_routes/search")
    @site.use("/api/search", require('./web/routes/api_routes/search'))
    @Logger.write("Registering Route ./web/routes/api_routes/message_history")
    @site.use("/api/message_history", require('./web/routes/api_routes/message_history'))
    @Logger.write("Registering Route ./web/routes/api_routes/twitch")
    @site.use("/twitch", require('./web/routes/twitch'))
    @Logger.write("Registering Route ./web/routes/api_routes/DiscordWebsocketEvent")
    @site.use("/api/DiscordWebsocketEvent", require('./web/routes/api_routes/DiscordWebsocketEvent'))
    @Logger.write("Registering Routes Complete")

    #redirect for when adding bot
    @site.get("/redirect", (req, res) ->
      #code = req.query.code
      guildId = req.query.guild_id
      #console.log req
      res.end(JSON.stringify({guildId: guildId, connected: true}))
    )


module.exports = WebServer
