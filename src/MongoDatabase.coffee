MongoClient = require('mongodb').MongoClient

class MongoDatabase

  constructor: (@Logger) ->


  connect: () ->
    self = @
    return new Promise((resolve, reject) ->
      MongoClient.connect('mongodb://localhost:27017/motorbot', (err, db) ->
        if err
          throw new Error("Failed to connect to database, exiting")
        self.Logger.write("Connected to Database")
        resolve(db)
      )
    )

module.exports = MongoDatabase