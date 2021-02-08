MongoClient = require('mongodb').MongoClient
keys = require '../keys.json'

class MongoDatabase

  constructor: (@Logger) ->


  connect: () ->
    self = @
    return new Promise((resolve, reject) ->
      self.Logger.write("Database; "+keys.mongo)
      MongoClient.connect(keys.mongo, (err, db) ->
        if err
          throw new Error("Failed to connect to database, exiting")
        self.Logger.write("Connected to Database")
        resolve(db)
      )
    )

module.exports = MongoDatabase