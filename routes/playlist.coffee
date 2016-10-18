express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
globals = require '../models/globals.coffee'
keys = require '../keys.json'
passport = require 'passport'
session = require('express-session')
cookieParser = require('cookie-parser')
bodyParser = require('body-parser')
DiscordStrategy = require('passport-discord').Strategy

#router.use(express.session({ secret: 'opqwekopre0kijoö94058732p9äowgjei' }));
router.use(bodyParser.json());
router.use(bodyParser.urlencoded({ extended: false }));
router.use(cookieParser("9`hIi6Z89*0gMHfYqLEJGfWMCK(d9YM0C"))
router.use(session({
  secret: '9`hIi6Z89*0gMHfYqLEJGfWMCK(d9YM0C',
  resave: true,
  saveUninitialized: true,
  name: "HexweaverBag"
}))
router.use(passport.initialize());
router.use(passport.session());

passport.serializeUser((user, done) ->
  sessionUser = {id: user.id, name: user.username, disc: user.discriminator, avatar: user.avatar, email: user.email, guilds: user.guilds}
  done(null, sessionUser)
)

passport.deserializeUser((sessionUser, done) ->
  done(null, sessionUser)
)

passport.use(new DiscordStrategy({
    clientID: keys.clientId,
    clientSecret: keys.clientSecret,
    scope: ["identify","email","guilds"],
    callbackURL: 'https://mb.lolstat.net/auth/discord/callback'
  },
  (accessToken, refreshToken, profile, cb) ->
    err = null
    return cb(err, profile)
))

router.get('/playlist', (req, res) ->
  sess = req.session
  if sess.passport
    userInChannel = false
    if sess.passport.user.guilds
      for guild in sess.passport.user.guilds
        if guild.id == "130734377066954752" then userInChannel = true
    if userInChannel
      res.render('playlist',{user: sess.passport.user})
    else
      res.end("Sorry, not in valid guild :(")
  else
    res.redirect('/auth/discord')
)

router.get('/auth/discord', passport.authenticate('discord'))
router.get('/auth/discord/callback', passport.authenticate('discord', {failureRedirect: '/auth/discord', session: true}), (req, res) ->
  res.redirect('/playlist')
)

router.get('/', (req, res, next) ->
  sess = req.session
  if sess.passport
    res.redirect('/playlist')
  else
    res.redirect('/auth/discord')
)

module.exports = router
