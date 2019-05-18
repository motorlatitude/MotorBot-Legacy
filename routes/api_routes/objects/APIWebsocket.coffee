class APIWebsocket

  constructor:(@req) ->

  send: (type, d) ->
    self = @
    if type == "SPOTIFY_IMPORT"
      self.req.app.locals.motorbot.websocket.broadcast(JSON.stringify({
        type: 'SPOTIFY_IMPORT',
        op: 9,
        d: {
          event_type: d.type,
          event_data: {
            user: self.req.user_id,
            start: d.importStartTime,
            message: d.message,
            progress: d.progress
          }
        }
      }), self.req.user_id)

module.exports = APIWebsocket