request = require 'request'

class SpotifyRefreshAccessToken

  constructor: () ->
    return (req, res, next) ->
      if req.user
        if req.user.connections
          if req.user.connections["spotify"]
            if req.user.connections["spotify"].refresh_token
              request({
                method: "POST",
                url: "https://accounts.spotify.com/api/token",
                json: true
                form: {
                  "grant_type": "refresh_token",
                  "refresh_token": req.user.connections["spotify"].refresh_token
                },
                headers: {
                  "Content-Type": "application/x-www-form-urlencoded"
                  "Authorization": "Basic "+new Buffer("935356234ee749df96a3ab1999e0d659:622b1a10ae054059bd2e5c260d87dabd").toString('base64')
                }
              }, (err, httpResponse, body) ->
                console.log err
                console.log body
                if body.access_token
                  usersCollection = req.app.locals.motorbot.Database.collection("users")
                  usersCollection.find({id: req.user.id}).toArray((err, result) ->
                    if err then console.log err
                    if result[0]
                      usersCollection.update({id: req.user.id},{$set: {"connections.spotify.access_token": body.access_token}}, (err, result) ->
                        if err then console.log err
                        if req.user
                          if req.user.connections
                            if req.user.connections["spotify"]
                              req.user.connections["spotify"].access_token = body.access_token
                        next()
                      )
                    else
                      console.log "User doesn't exist"
                      next()
                  )
                else
                  console.log "No Access Token was returned"
                  next()
              )
            else
              next()
          else
            next()
        else
          next()
      else
        next()


module.exports = SpotifyRefreshAccessToken