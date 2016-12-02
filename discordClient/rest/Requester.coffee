u = require('../utils.coffee')
utils = new u()
Constants = require './../constants.coffee'
keys = require './../../keys.json'
req = require 'request'

class Requester

  constructor: () ->
    @host = Constants.api.host

  dataOrCallback: (data) ->
    if typeof data == "object"
      return {data: data, cb:cb}
    else if typeof data == "function"
      return {data: {}, cb:cb}
    else
      return {data: {}, cb: undefined}

  sendRequest: (method, endpoint, data) ->
    self = @
    return new Promise((resolve, reject) ->
      req({
        url: self.host+endpoint,
        method: method
        headers: {
          "Authorization": "Bot "+keys.token
        },
        json: true
        body: data
      }, (err, httpResponse, body) ->
          #console.log body
          status = httpResponse.statusCode
          utils.debug(status+" "+httpResponse.statusMessage+" => "+method+" - "+endpoint)
          if err
            reject(err)
          else if status == 400 || status == 401 || status == 403 || status == 404 || status == 405 || status == 429 || status == 502 || status == 500
            reject({statusCode: status, statusMessage: httpResponse.statusMessage, body: body})
          else
            resolve({httpResponse: httpResponse, body: body})
        )
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
      json: true
    }, (err, httpResponse, body) ->
      return body
    )
    form = r.form();
    form.append('file', file, {filename: filename})

module.exports = Requester