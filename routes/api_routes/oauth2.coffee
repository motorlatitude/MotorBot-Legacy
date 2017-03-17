express = require 'express'
router = express.Router()
passport = require 'passport'
session = require('express-session')
LocalStrategy = require('passport-local').Strategy
crypto = require('crypto')
uuid = require 'node-uuid'

###
  OAUTH 2.0

  https://mb.lolstat.net/api/oauth2/
###

passport.serializeUser((user, done) ->
  done(null, user.id)
)

passport.deserializeUser((req, id, done) ->
  usersCollection = req.app.locals.motorbot.database.collection("users")
  usersCollection.find({id: id}).toArray((err, results) ->
    if results[0]
      done(null, results[0])
  )
)

passport.use(new LocalStrategy({
    usernameField: 'user',
    passwordField: 'pass',
    passReqToCallback: true,
    session: false
  },
    (req, username, password, cb) ->
      usersCollection = req.app.locals.motorbot.database.collection("users")
      usersCollection.find({localUsername: username}).toArray((err, result) ->
        if err then return cb(err)
        if result[0]
          salt = result[0].localSalt
          hash = crypto.createHmac('sha512', salt)
          hash.update(password)
          hashPass = hash.digest('hex')
          if result[0].localPassword == hashPass
            return cb(null, result[0])
          else
            return cb(null, false, {message: "Incorrect Username or Password"})
        else
          return cb(null, false, {message: "Incorrect Username or Password"})
      )
  )
)

authError = (res, error, error_description, error_uri = undefined) ->
  return res.status(400).render("AuthenticationError", {error: error, error_description: error_description, error_uri: error_uri})

authorization = (req, res, next) ->
  # REQUIRED
  client_id = req.query.client_id
  redirect_uri = req.query.redirect_uri
  response_type = req.query.response_type
  if !client_id then return authError(res, "invalid_client", "Client ID Not Recognised")
  if !redirect_uri then return authError(res, "invalid_request", "Missing Redirect URI")
  if !response_type then return authError(res, "invalid_request", "Missing Response Type")

  if response_type == "code"
    APIAccessCollection = req.app.locals.motorbot.database.collection("apiaccess")
    APIAccessCollection.find({id: client_id}).toArray((err, result) ->
      if err then return authError(res, "unknown_error", "Internal Database Error")
      if result[0]
        next()
      else
        return authError(res, "invalid_client", "Client ID Not Recognised")
    )
  else
    return authError(res, "invalid_request", "Invalid Response Type")


router.get("/authorize", authorization, (req, res) ->
  if req.user
    AuthorizationCodesCollection = req.app.locals.motorbot.database.collection("authorizationCodes")
    authorizationcode = crypto.randomBytes(16).toString('hex')
    code = {
      value: authorizationcode
      client_id: req.query.client_id.toString()
      redirect_uri: req.query.redirect_uri.toString()
      user_id: req.user.id
    }
    AuthorizationCodesCollection.insertOne(code, (err, results) ->
      res.redirect(req.query.redirect_uri.toString()+"?code="+authorizationcode)
    )
  else
    res.render("oauthlogin",{err: req.flash('error')})
)

router.post("/authorize", authorization, passport.authenticate('local', {failureRedirect : '/', failureFlash: true, session: false}), (req, res) ->
  if req.user
    client_id = req.query.client_id.toString()
    AuthorizationCodesCollection = req.app.locals.motorbot.database.collection("authorizationCodes")
    authorizationcode = crypto.randomBytes(16).toString('hex')
    code = {
      value: authorizationcode
      client_id: client_id
      redirect_uri: req.query.redirect_uri.toString()
      user_id: req.user.id
      expires: new Date().getTime() + 60000
    }
    AuthorizationCodesCollection.insertOne(code, (err, results) ->
      res.redirect(req.query.redirect_uri.toString()+"?code="+authorizationcode)
      setTimeout(() ->
        #delete authorization code after 10 minutes
        AuthorizationCodesCollection.remove({value: authorizationcode, client_id: client_id}, (err, result) ->
          if err then console.log err
        )
      ,60000)
    )
  else
    return authError(res, "unauthorized_client", "Client Is Not Authorised")
)

router.post("/token", (req, res) ->
  grant_type = req.body.grant_type #Required
  code = req.body.code #Requried
  redirect_uri = req.body.redirect_uri #Required
  client_id = req.body.client_id #Required
  client_secret = req.body.client_secret #Required
  authorization = req.get("authorization")
  if authorization #recommended approach
    credentials = new Buffer(auth.split(" ").pop(), "base64").toString("ascii").split(":");
    client_id = credentials[0]
    client_secret = credentials[1]
  if grant_type == "authorization_code"
    APIAccessCollection = req.app.locals.motorbot.database.collection("apiaccess")
    APIAccessCollection.find({id: client_id, secret: client_secret}).toArray((err, result) ->
      if err then return authError(res, "unknown_error", "Internal Database Error")
      if result[0]
        AuthorizationCodesCollection = req.app.locals.motorbot.database.collection("authorizationCodes")
        AuthorizationCodesCollection.find({value: code.toString(), client_id: client_id, redirect_uri: redirect_uri}).toArray((err, result) ->
          if err then return authError(res, "unknown_error", "Internal Database Error")
          if result[0]
            if new Date().getTime() <= result[0].expires
              user_id = result[0].user_id
              #delete authorization code after use
              AuthorizationCodesCollection.remove({value: code.toString(), client_id: client_id}, (err, result) ->
                if err then return authError(res, "unknown_error", "Internal Database Error")
                AccessTokenCollection = req.app.locals.motorbot.database.collection("accessTokens")
                accesstoken = crypto.randomBytes(64).toString('hex')
                accesstokenObj = {
                  value: accesstoken,
                  clientId: client_id,
                  userId: user_id,
                  expires: new Date().getTime() + 86400000
                }
                AccessTokenCollection.remove({clientId: client_id, userId: user_id}, (err, results) ->
                  if err then return authError(res, "unknown_error", "Internal Database Error")
                  AccessTokenCollection.insertOne(accesstokenObj, (err, result) ->
                    if err then return authError(res, "unknown_error", "Internal Database Error")
                    res.type("json")
                    res.send(JSON.stringify({"access_token": accesstoken, "expires": 86400, "token_type": "bearer"}))
                  )
                )
              )
            else
              AuthorizationCodesCollection.remove({value: code.toString(), client_id: client_id}, (err, result) ->
                return authError(res, "unauthorized_client", "Authorization Grant Expired")
              )
          else
            return authError(res, "invalid_request", "Value Mismatch")
        )
      else
        return authError(res, "unauthorized_client", "Client Authorisation Failed")
    )
  else if grant_type == ""

  else
    return authError(res, "unsupported_grant_type", "Unknown Grant Type")
)

router.get("/tokeninfo", (req, res) ->
  token = req.query.token
  res.type("json")
  if token
    AccessTokenCollection = req.app.locals.motorbot.database.collection("accessTokens")
    AccessTokenCollection.find({value: token.toString()}).toArray((err, result) ->
      if err then res.status(500).send({code: 500, status: "Internal Server Error"})
      if result[0]
        tokeninfo = result[0]
        tokeninfo.valid = true
        res.send(tokeninfo)
      else
        res.status(404).send({code: 404, status: "Token Not Found"})
    )
  else
    res.status(400).send({code: 400, status: "Bad Request - Missing token"})
)

router.get("/revoke", (req, res) ->

)

module.exports = router