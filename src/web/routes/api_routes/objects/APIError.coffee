

class APIError extends Error

  constructor:(ctx, message) ->
    super(message)
    Error.captureStackTrace(this, APIError)
    this.message = message
    this.name = ctx.constructor.name


module.exports = APIError