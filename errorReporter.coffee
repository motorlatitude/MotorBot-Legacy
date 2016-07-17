class exports.ErrorReport extends Error

  constructor: (msg, cb) ->
    super msg
    @name = msg.name || "Unknown Error"
    @message = msg.message
    @stackTrace = Error.captureStackTrace(@, ErrorReport)
    arr = []
    arr.name = @name
    arr.message = @message
    arr.stack = msg.stack
    return cb(arr)
