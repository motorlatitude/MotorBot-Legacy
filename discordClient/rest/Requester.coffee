Constants = require './../constants.coffee'
keys = require './../../keys.json'
req = require 'request'

class Requester

  constructor: () ->
    @host = Constants.api.host
    
  sendRequest: (method, endpoint, data) ->
    req({
      url: @host+endpoint,
      method: method
      headers: {
        "Authorization": "Bot "+keys.token
      },
      form: data
    }, (err, httpResponse, body) ->
    )

  sendUploadRequest: (method,endpoint, data, file, filename) ->
    r = req({
      url: @host+endpoint,
      method: method
      headers: {
        "Authorization": "Bot "+keys.token,
        "Content-Type": "multipart/form-data"
      },
      form: data
    }, (err, httpResponse, body) ->

    )
    form = r.form();
    form.append('file', file, {filename: filename})

module.exports = Requester