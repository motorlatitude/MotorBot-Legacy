passport = require 'passport'
SpotifyStrategy = require('passport-spotify').Strategy

class PassportSpotify

  constructor: () ->
    passport.serializeUser((user, done) ->
      done(null, user.id)
    )

    passport.deserializeUser((req, id, done) ->
      usersCollection = req.app.locals.motorbot.Database.collection("users")
      usersCollection.find({id: id}).toArray((err, results) ->
        if results[0]
          done(null, results[0])
      )
    )

    passport.use(new SpotifyStrategy({
        clientID: "935356234ee749df96a3ab1999e0d659",
        clientSecret: "622b1a10ae054059bd2e5c260d87dabd",
        callbackURL: "https://motorbot.io/api/spotify/callback",
        passReqToCallback: true
      },
        (req, accessToken, refreshToken, profile, done) ->
          usersCollection = req.app.locals.motorbot.Database.collection("users")
          usersCollection.find({id: req.user.id}).toArray((err, result) ->
            if err then done(err, undefined)
            if result[0]
              connections = {}
              if result[0].connections then connections = result[0].connections
              connections["spotify"] = {
                username: profile.username
                access_token: accessToken
                refresh_token: refreshToken
                expires: new Date().getTime() + 3600
                sync: true
              }
              usersCollection.update({id: req.user.id},{$set: {connections: connections}}, (err, result) ->
                if err
                  done(err, undefined)
                else
                  done(err, profile)
              )
            else
              done(err, undefined)
          )
      )
    )

    return passport

module.exports = PassportSpotify