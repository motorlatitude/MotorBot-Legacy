
class User

  constructor:(@req) ->
    @database = @req.app.locals.motorbot.database.collection("users")

  userById: (user_id, filter = {}) ->
    self = @
    filter['_id'] = 0
    return new Promise((resolve, reject) ->
      self.database.find({id: user_id}, filter).toArray((err, results) ->
        if err then reject({error: "DATABASE_ERROR", message: err})
        if results[0]
          resolve(results[0])
        else
          resolve({})
      )
    )

module.exports = User