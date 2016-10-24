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
  done(null, user.id)
)

passport.deserializeUser((id, done) ->
  usersCollection = globals.db.collection("users")
  usersCollection.find({id: id}).toArray((err, results) ->
    if results[0]
      done(null, results[0])
  )
)

passport.use(new DiscordStrategy({
    clientID: keys.clientId,
    clientSecret: keys.clientSecret,
    scope: ["identify","guilds"],
    callbackURL: 'https://mb.lolstat.net/auth/discord/callback'
  },
  (accessToken, refreshToken, profile, cb) ->
    usersCollection = globals.db.collection("users")
    usersCollection.find({id: profile.id}).toArray((err, results) ->
      if err then console.log err
      if results[0]
        return cb(err, profile)
      else
        userObj = {
          id: profile.id,
          username: profile.username,
          discriminator: profile.discriminator,
          avatar: profile.avatar,
          guilds: profile.guilds,
          playlists: []
        }
      usersCollection.insertOne(userObj, (err, result) ->
        if err then console.log err
        return cb(err, profile)
      )
    )
))

router.get('/playlist', (req, res) ->
  sess = req.session
  if req.user
    userInChannel = false
    if req.user.guilds
      for guild in req.user.guilds
        if guild.id == "130734377066954752" then userInChannel = true
    if userInChannel
      res.render('playlist',{user: req.user})
    else
      res.end("Sorry, not in valid guild :(")
  else
    res.redirect('/auth/discord')
)

router.get('/views/:view/:param?', (req, res) ->
  sess = req.session
  if req.user
    userInChannel = false
    if req.user.guilds
      for guild in req.user.guilds
        if guild.id == "130734377066954752" then userInChannel = true
    if userInChannel
      if req.params.view
        if req.params.view == "playlists" && req.params.param
          res.render("playlistView",{user: req.user, playlistId: req.params.param})
        else if req.params.view == "playlists"
          res.render("playlists",{user: req.user})
        else
          res.render(req.params.view,{user: req.user})
      else
        res.end("You seem lost m9")
    else
      res.end("Sorry, not in valid guild :(")
  else
    res.redirect('/auth/discord')
)

router.get('/dashboard/:view/:param?', (req, res) ->
  sess = req.session
  if req.user
    userInChannel = false
    if req.user.guilds
      for guild in req.user.guilds
        if guild.id == "130734377066954752" then userInChannel = true
    if userInChannel
      if req.params.view == "playlists"
        if req.params.param
          res.render('layout',{user: req.user, view: 'playlists', param: req.params.param})
        else
          res.render('layout',{user: req.user, view: 'playlists', param: undefined})
      else if req.params.view == "home"
        res.render('layout',{user: req.user, view: 'home', param: undefined})
      else if req.params.view == "queue"
        res.render('layout',{user: req.user, view: 'queue', param: undefined})
      else
        res.render('layout',{user: req.user, view: 'home', param: undefined})
    else
      res.end("Sorry, not in valid guild :(")
  else
    res.redirect('/auth/discord')
)

router.get('/auth/discord', passport.authenticate('discord'))
router.get('/auth/discord/callback', passport.authenticate('discord', {failureRedirect: '/auth/discord', session: true}), (req, res) ->
  res.redirect('/dashboard/home')
)

router.get('/', (req, res, next) ->
  sess = req.session
  if req.user
    res.redirect('/dashboard/home')
  else
    res.redirect('/auth/discord')
)

module.exports = router
