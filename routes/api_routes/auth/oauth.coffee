class OAuth

  constructor: () ->
    return (req, res, next) ->
      if !req.query.api_key
        return res.status(401).send({code: 401, status: "No API Key Supplied"})
      else
        APIAccessCollection = req.app.locals.motorbot.database.collection("apiaccess")
        APIAccessCollection.find({key: req.query.api_key}).toArray((err, results) ->
          if err then console.log err
          if results[0]
            client_id = results[0].id
            if req.headers["authorization"]
              bearerHeader = req.headers["authorization"]
              if typeof bearerHeader != 'undefined'
                bearer = bearerHeader.split(" ")
                bearerToken = bearer[1]
                accessTokenCollection = req.app.locals.motorbot.database.collection("accessTokens")
                accessTokenCollection.find({value: bearerToken}).toArray((err, result) ->
                  if err then console.log err
                  console.log result
                  if result[0]
                    if client_id == result[0].clientId
                      req.user_id = result[0].userId
                      req.client_id = result[0].clientId
                      usersCollection = req.app.locals.motorbot.database.collection("users")
                      usersCollection.find({id: result[0].userId}).toArray((err, userResults) ->
                        if err then console.log err
                        if userResults[0]
                          req.user = userResults[0]
                          return next()
                        else
                          return res.status(401).send({code: 401, status: "Unknown User"})
                      )
                    else
                      return res.status(401).send({code: 401, status: "Client Unauthorized"})
                  else
                    return res.status(401).send({code: 401, status: "Unknown Access Token"})
                )
              else
                return res.status(401).send({code: 401, status: "No Token Supplied"})
            else
              return res.status(401).send({code: 401, status: "No Token Supplied"})
          else
            return res.status(401).send({code: 401, status: "Unauthorized"})
        )


module.exports = OAuth