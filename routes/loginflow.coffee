express = require 'express'
router = express.Router()
keys = require '../keys.json'
passport = require 'passport'
session = require 'express-session'
DiscordStrategy = require('passport-discord').Strategy
OAuth2Strategy = require('passport-oauth2').Strategy
crypto = require('crypto')
uuid = require 'node-uuid'
request = require 'request'

passport.serializeUser((user, done) ->
  done(null, user.id)
)

passport.deserializeUser((req, id, done) ->
  usersCollection = req.app.locals.motorbot.database.collection("users")
  karmaCollection = req.app.locals.motorbot.database.collection("karma_points")
  usersCollection.find({id: id}).toArray((err, results) ->
    karmaCollection.find({author: id}).toArray((err, karma_points) ->
      if err then console.log err
      if karma_points[0]
        results[0].karma = 0
        results[0].karma = karma_points[0].karma
      if results[0]
        done(null, results[0])
    )
  )
)

#MB Login
passport.use(new OAuth2Strategy({
    authorizationURL: 'https://motorbot.io/api/oauth2/authorize',
    tokenURL: 'https://motorbot.io/api/oauth2/token',
    clientID: '7c78862088c0228ca226f4462df3d4ff',
    clientSecret: '2bd12fcaf92bb63d7c11b0b6858d9d3e1c2c966cb17aa0152c9e07bdfca9535b',
    callbackURL: "https://motorbot.io/loginflow/callback",
    state: true,
    session: true,
    passReqToCallback: true
  }, (req, accessToken, refreshToken, profile, cb) ->
    accessTokenCollection = req.app.locals.motorbot.database.collection("accessTokens")
    accessTokenCollection.find({value: accessToken}).toArray((err, result) ->
      if err
        console.log err
        cb(err)
      if result[0]
        usersCollection = req.app.locals.motorbot.database.collection("users")
        usersCollection.find({id: result[0].userId}).toArray((err, result) ->
          if err
            console.log err
            cb(err)
          if result[0]
            profile = result[0]
            profile.motorbotAccessToken = accessToken
            usersCollection.update({id: profile.id}, {$set:{motorbotAccessToken: accessToken}}, (err, result) ->
              if err then console.log err
              return cb(err, profile)
            )
          else
            return cb(null, false)
        )
      else
        return cb(null, false)
    )
  )
)
#Discord verification OAuth
passport.use(new DiscordStrategy({
  clientID: keys.clientId,
  clientSecret: keys.clientSecret,
  scope: ["identify","guilds"],
  callbackURL: 'https://motorbot.io/loginflow/register/discord/callback'
  passReqToCallback: true
},
  (req, accessToken, refreshToken, profile, cb) ->
    usersCollection = req.app.locals.motorbot.database.collection("users")
    usersCollection.find({id: profile.id}).toArray((err, results) ->
      if err then console.log err
      if results[0]
        usersCollection.update({id: profile.id}, {$set:{avatar: profile.avatar, username: profile.username, guilds: profile.guilds, discordAuth:{accessToken: accessToken, refreshToken: refreshToken}}}, (err, result) ->
          if err then console.log err
          return cb(err, profile)
          ###
          developer = {
            key: uuid.v4()
            id: crypto.randomBytes(16).toString('hex')
            secret: crypto.randomBytes(32).toString('hex')
            tokens: []
            userId: profile.id
          }
{"key": "caf07b8b-366e-44ab-9bda-152a42g8d1ef","id": “1a23590021f0168gz276f43d1de3d6ef","secret": "2bd12fcaf92bb63d7c99b1b2398e1f3e1c2c166cb17g40152c9e07asdfg9535b","tokens":[],"userId": "95164972807487488","title": "Motorbot Chrome Extension“}
  ###
        )
      else
        userObj = {
          id: profile.id,
          username: profile.username,
          discriminator: profile.discriminator,
          avatar: profile.avatar,
          guilds: profile.guilds,
          playlists: ["YFX7clE6pCquMNnsHtxlzgJiHXIixFxk"],
          accessToken: accessToken,
          refreshToken: refreshToken
        }
        usersCollection.insertOne(userObj, (err, result) ->
          if err then console.log err
          return cb(err, profile)
        )
    )
))
###
  LOGINFLOW

  https://motorbot.io/loginflow/
###

refreshDiscordAccessToken = (req, refresh_token, cb) ->
  refresh_package = {
    "grant_type": "refresh_token",
    "refresh_token": refresh_token,
    "client_id": keys.clientId,
    "client_secret": keys.clientSecret,
    "redirect_uri": "https://motorbot.io/loginflow/register/discord/callback",
    "scope": "identify guilds"
  }
  console.log refresh_package
  request({
      method: "POST",
      url: "https://discordapp.com/api/oauth2/token",
      json: true
      form: refresh_package,
      headers: {
        "Content-Type": "application/x-www-form-urlencoded"
      }
    }, (err, httpResponse, body) ->
    if err
      console.log "---------ACCESS TOKEN ERROR----------"
      console.log err
    console.log "---------ACCESS TOKEN UPDATE---------"
    console.log body
    if body.access_token
      usersCollection = req.app.locals.motorbot.database.collection("users")
      usersCollection.update({id: req.user.id},{$set: {"discordAuth": {accessToken: body.access_token, refreshToken: body.refresh_token, expires: (new Date().getTime() + parseInt(body.expires_in))}}}, (err, result) ->
        if err then console.log err
        if typeof cb == "function" then cb(body.access_token)
      )
    else
      if typeof cb == "function" then cb()
  )

getDiscordUserData = (req, access_token, cb) ->
  request({
      method: "GET",
      url: "https://discordapp.com/api/v6/users/%40me",
      json: true
      headers: {
        "Authorization": "Bearer "+access_token
      }
    },
    (err, httpResponse, body) ->
      if err
        console.log "---------USER DATA ERROR----------"
        console.log err
      console.log "---------USER DATA UPDATE---------"
      console.log body
      if body.id
        profile = body
        usersCollection = req.app.locals.motorbot.database.collection("users")
        usersCollection.update({id: profile.id}, {$set:{avatar: profile.avatar, username: profile.username, discriminator: profile.discriminator, email: profile.email}}, (err, result) ->
          if err then console.log err
          getDiscordUserGuildData(req, profile.id, access_token, cb)
        )
      else
        console.log("No user data returned from discord :(")
        if typeof cb == "function" then cb()
  )

getDiscordUserGuildData = (req, user_id, access_token, cb) ->
  request({
    method: "GET",
    url: "https://discordapp.com/api/v6/users/%40me/guilds",
    json: true
    headers: {
      "Authorization": "Bearer "+access_token
    }
  },
    (err, httpResponse, body) ->
      if err
        console.log "---------USER GUILD DATA ERROR----------"
        console.log err
      if body
        console.log "---------USER GUILD DATA UPDATE---------"
        #console.log body
        guilds = body
        usersCollection = req.app.locals.motorbot.database.collection("users")
        usersCollection.update({id: user_id}, {$set:{guilds: guilds}}, (err, result) ->
          if err then console.log err
          if typeof cb == "function" then cb()
        )
      else
        console.log("No user guild data returned from discord :(")
        if typeof cb == "function" then cb()
  )

refreshDiscordUserData = (req, res, next) ->
  usersCollection = req.app.locals.motorbot.database.collection("users")
  usersCollection.find({id: req.user.id}).toArray((err, results) ->
    if err then console.log err
    if results[0]
      if results[0].discordAuth
        if results[0].discordAuth.expires <= new Date().getTime()
          #discord accesstoken expired, refresh
          console.log "Discord Access Token Has Expired"
          refreshDiscordAccessToken(req, results[0].discordAuth.refreshToken, (access_token) ->
            getDiscordUserData(req, access_token, () ->
              next()
            )
          )
        else
          getDiscordUserData(req, results[0].discordAuth.accessToken, () ->
            next()
          )
      else
        if results[0].refreshToken
          refreshDiscordAccessToken(req, results[0].refreshToken, (access_token) ->
            getDiscordUserData(req, access_token, () ->
              next()
            )
          )
        else
          console.log("??????1")
          next()
    else
      #wtf, you've logged in but you don't exist?
      console.log("??????2")
      next()
  )

router.get("/", passport.authenticate('oauth2'))

###
router.post("/login",  passport.authenticate('local', { failureRedirect: '/loginflow?err=true', session: true}), (req, res) ->
  console.log "Logged In"
  res.redirect("/")
)
###

router.get("/callback", passport.authenticate('oauth2', { failureRedirect: '/?err=true', session: true}), refreshDiscordUserData, (req, res) ->
  if req.user
    console.log "Logged In"
    res.redirect("/dashboard/home")
)

router.get("/register", (req, res) ->
  res.render("register")
)

router.get("/register/discord", passport.authenticate('discord'))

router.get("/register/discord/callback", passport.authenticate('discord', {failureRedirect: '/register', session: true}), (req, res) ->
  res.redirect("/loginflow/register/createAccount/")
)

router.get("/register/createAccount/", (req, res) ->
  if req.user
    res.render("CreateAccount")
)

router.post("/register", (req, res) ->
  if req.user
    user = req.body.user
    pass = req.body.pass
    repeat_pass = req.body.repeat_pass
    if pass != repeat_pass
      res.render("CreateAccount",{err: "Passwords don't match :("})
    else
      salt = crypto.randomBytes(32).toString('hex')
      hash = crypto.createHmac('sha512', salt)
      hash.update(pass.toString())
      hashPass = hash.digest('hex')
      usersCollection = req.app.locals.motorbot.database.collection("users")
      usersCollection.find({localUsername: req.body.user}).toArray((err, result) ->
        if err then console.log err
        if !result[0]
          usersCollection.update({id: req.user.id}, {$set:{localUsername: user.toString(), localPassword: hashPass, localSalt: salt}}, (err, result) ->
            if err then console.log err
            req.logout()
            res.render("CreateAccountDone")
          )
        else
          res.render("CreateAccount",{err: "Username Already In Use"})
      )
  else
    res.redirect("/loginflow/register")
)

router.get("/logout", (req, res) ->
  req.logout()
  res.redirect("/")
)

module.exports = router