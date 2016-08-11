MongoClient = require('mongodb').MongoClient

class exports.Playlist

  createDBConnection: (cb) ->
    MongoClient.connect('mongodb://localhost:27017/motorbot', (err, db) ->
      if err
        throw new Error("Failed to connect to database, exiting")
      cb(db)
    )

  db: (cb) =>
    @createDBConnection((db) ->
      return cb(db)
    )
