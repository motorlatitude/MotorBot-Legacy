class api

  constructor: () ->
    return (req, res, next) ->
      if !req.query.api_key
        return res.status(401).send({code: 401, status: "No API Key Supplied"})
      else
        APIAccessCollection = req.app.locals.motorbot.Database.collection("apiaccess")
        APIAccessCollection.find({key: req.query.api_key}).toArray((err, results) ->
          if err then console.log err
          if results[0]
            return next()
          else
            return res.status(401).send({code: 401, status: "Unauthorized"})
        )

module.exports = api