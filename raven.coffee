{ErrorReport} = require(__dirname+'/errorReporter.coffee')
crypto = require('crypto')
http = require('http')
url = require('url')
os = require('os')
fs = require('fs')
path = require('path')
stacktrace = require('stack-trace')
requestModule = require('request')

class Raven

  constructor: (@dsn, @options=undefined, callback=undefined) ->
    console.log "Inititiating Raven"
    @organisationId = @dsn.replace('http://','').split(":")[1].split("@")[0] #crypto.createHash('md5').update(@project.split('/')[0]+'+'+@apiKey).digest('hex')
    @projectId = @dsn.replace('http://','').split(":")[0] #crypto.createHash('md5').update(@project.split('/')[1]+'+'+@apiKey).digest('hex')
    @release = undefined
    @tags = []
    @serverName = undefined
    @ignoreErrors = undefined
    self = @
    if @options
      if @options.tags
        @tags = @options.tags
      if @options.release #release set
        @release = @options.release
        @tags.push({release: @release})
      if @options.serverName
        @serverName = @options.serverName
        @tags.push({serverName: @serverName})
      if @options.ignoreErrors
        #string or regular expression for which the error message is seached for, if it contains such a string raven will not send the event on to sentry
        @ignoreErrors = @options.ignoreErrors

    process.on("uncaughtException", (err) ->
      console.log "Uncaught Exception, Exiting"
      self.captureException(err,{level:'fatal'}, (d) ->
        process.exit(1)
      )
    )

    reqData = JSON.stringify({'init': true})
    auth = 'Basic ' + new Buffer(@projectId + ':' + @organisationId).toString('base64')
    options =
      host: '188.166.156.69'
      port: 3001
      path: '/api/init'
      method: 'POST'
      headers:
        'User-Agent': 'LoLStat-Website'
        'Accept-Language': 'en-GB'
        'Accept-Charset': 'ISO-8859-1,utf-8'
        'Content-Type': 'application/json'
        'Content-Length': Buffer.byteLength(reqData)
        'Authorization': auth

    req = http.request(options, (response) ->
      data = ''
      response.on('data', (d) ->
        data += d
      )
      response.on('end', () ->
        if callback
          if response.statusCode == 200
            callback(null, JSON.parse(data))
          else
            callback(response.statusCode+" - "+response.statusMessage, null)
      )
    )
    req.write(reqData)
    req.on('error', (e) ->
      if callback
        callback("Connection to Sentry Refused "+e, null)
      console.log "Connection to Sentry Refused"
    )

  ###
    captureException(err,{level:'debug'},())
    captureException(err,())
    captureException(err,{level:'debug'})
    captureException(err)

   #options
    level: debug|info|warning|error|fatal|
    tags: {key: "value"}
    details: string containing details of the error/exception
  ###

  main_module = (require.main && path.dirname(require.main.filename) || process.cwd()) + '/'

  getModule: (filename, base) ->
    if (!base)
      base = main_module

    file = path.basename(filename, '.js')
    filename = path.dirname(filename)
    n = filename.lastIndexOf('/node_modules/')
    if n > -1
      return filename.substr(n + 14).replace(/\//g, '.') + ':' + file
    n = (filename + '/').lastIndexOf(base, 0)
    if n == 0
      module = filename.substr(base.length).replace(/\//g, '.')
      if module
        module += ':'
      module += file
      return module
    return file

  parseStack: (err, cb) =>
    frames = []
    cache = {}
    stacks = stacktrace.parse(err)

    if !stacks || !Array.isArray(stacks) || !stacks.length || !stacks[0].getFileName
      return cb(frames)
    callbacks = stacks.length
    stacks.reverse()
    self = @
    stacks.forEach( (line, index) ->
      frame = {}
      frame['function'] = line.getTypeName() + '.' + (line.getMethodName() || '<anonymous>')
      frame.filename = line.getFileName() || ''
      frame.isInternal = "cookie"
      frame.isInternal = line.isNative() || frame.filename[0] != '/' && frame.filename[0] != '.'
      frame.lineno = line.getLineNumber() || 0
      frame.columnno = line.getColumnNumber() || 0
      frame.module = self.getModule(frame.filename) || ''
      frame.in_app = "cookie"
      frame["in_app"] = !frame.isInternal && !~frame.filename.indexOf('node_modules/')

      if frame.isInternal
        frames[index] = frame
        if --callbacks == 0
          cb(frames)
        return

      if frame.filename in cache
        parseLines(cache[frame.filename])
        if (--callbacks == 0)
          cb(frames)
        return

      fs.readFile(frame.filename, (_err, file) ->
        if !_err
          lines = file.toString().split('\n')
          cache[frame.filename] = lines
          frame.pre_context = lines.slice(Math.max(0, frame.lineno - (7 + 1)), frame.lineno - 1)
          frame.line_context = lines[frame.lineno - 1]
          frame.post_context = lines.slice(frame.lineno, frame.lineno + 7)
        frames[index] = frame
        if --callbacks == 0
          cb(frames)
      )
    )

  parseRequest: (req) ->
    ## request parameters
    output = {}
    if (req.request)
      req = req.request
      headers = req.headers || req.header || {}
      method = req.method || req.request.method
      host = req.hostname || req.host || headers.host || "<no host>"
      protocol = req.uri.protocol || "http"
      actualUrl = req.href || ""
      relativePath = req.uri.pathname || req.uri.path
      output["request"] = {
        method: method
        headers: headers
        host: host
        protocol: protocol
        url: actualUrl
        relativePath: relativePath
      }
      if(req.response)
        res = req.response
        headers = res.headers || res.header || {}
        method = res.method
        statusCode = res.statusCode || 0
        statusMessage = res.statusMessage || ""
        status = statusCode+" "+statusMessage
        data = res.body
        if(data && {}.toString.call(data) != "[object String]")
          data = JSON.stringify(data)
        output["response"] = {
          method: method
          headers: headers
          data: data
          status: status
          statusCode: statusCode
          statusMessage: statusMessage
        }
    else
      headers = req.headers || req.header || {}
      method = req.method
      data = req.body
      statusCode = req.statusCode || 0
      statusMessage = req.statusMessage || ""
      status = statusCode+" "+statusMessage
      if(data && {}.toString.call(data) != "[object String]")
        data = JSON.stringify(data)
      output["response"] = {
        method: method
        headers: headers
        data: data
        status: status
        statusCode: statusCode
        statusMessage: statusMessage
      }
    return output


  captureException: (exception, optionsOrCallback, callback=undefined) =>
    options = optionsOrCallback
    postValues = {level: "error", tags: [], details: "", extra: {}, request:{}, release: undefined}
    postValues.errorValues = {}
    if typeof options == "function" #exception and callback sent
      options = callback
    else if typeof options == undefined #only exception sent
      options = []
      callback = undefined
    else if typeof options == "object" #option and potentialy callback sent (if no callback, undefined will be returned when calling cb)
      if options.level.match(/^(?:debug|info|warn|error|fatal)$/)
        postValues.level = options.level
      if typeof options.tags == "object"
        postValues.tags = options.tags
      if typeof options.details == "string"
        postValues.details = options.details
      if typeof options.extra == "object"
        postValues.extra = options.extra
      if typeof options.request == "object"
        postValues.request = @parseRequest(options.request)

    if @release
      postValues.release = @release
    extendArray = (a, b) ->
      for i in b
        a.push(i)
      return a
    postValues.tags = extendArray(postValues.tags, @tags)
    postValues.tags.push({"level": postValues.level})
    postValues.tags.push({"server_platform": os.platform()})
    postValues.tags.push({"platform": "nodejs"})
    postValues.timestamp = new Date().getTime()
    postValues.project = @projectId
    postValues.org = @organisationId
    self = @
    if typeof exception == "object"
      new ErrorReport(exception, (output) ->
        console.log "# Raven ("+postValues.level+"): "+output.message
        console.log output.stack
        #postValues.fingerprint = crypto.createHash('md5').update(output.message+'+'+output.stack).digest('hex')
        postValues.errorValues.message = output.message
        postValues.errorValues.name = output.name
        postValues.errorValues.stack = output.stack
        stackTrace = self.parseStack(exception, (frames) ->
          postValues.stackTrace = frames
          for frame in frames.reverse()
            if frame.in_app && frame.module != "lib:Raven.coffee"
              postValues.fingerprint = crypto.createHash('md5').update(frame.filename+frame.line_context).digest('hex')
              break
          self.sendr(postValues, callback)
        )
      )
    else if typeof exception == "string"
      console.log "# Raven ("+postValues.level+"): "+exception
      postValues.errorValues.message = exception
      postValues.errorValues.name = postValues.level
      ourError = new Error()
      stack = ourError.stack
      stackSplit = stack.split("\n")
      postValues.errorValues.stack = stack.replace(stackSplit[0]+"\n","")
      #postValues.fingerprint = crypto.createHash('md5').update(exception+'+'+postValues.errorValues.stack).digest('hex')
      stackTrace = self.parseStack(ourError, (frames) ->
        postValues.stackTrace = frames
        for frame in frames.reverse()
          if frame.in_app && frame.module != "lib:Raven.coffee"
            postValues.fingerprint = crypto.createHash('md5').update(frame.filename+frame.line_context).digest('hex')
            break
        self.sendr(postValues, callback)
      )
    else
      self.captureException(new Error("Sentry: Unknown Exception (should be string/object)"),{level: 'error'})
      callback()

  sendr: (postValues,callback) =>
    data = JSON.stringify(postValues)
    auth = 'Basic ' + new Buffer(@projectId + ':' + @organisationId).toString('base64')
    options =
      host: '188.166.156.69'
      port: 3001
      path: '/api/store'
      method: 'POST'
      headers:
        'User-Agent': 'LoLStat-Website'
        'Accept-Language': 'en-GB'
        'Accept-Charset': 'ISO-8859-1,utf-8'
        'Content-Type': 'application/json'
        'Content-Length': Buffer.byteLength(data)
        'Authorization': auth

    req = http.request(options, (response) ->
      data = ''
      response.on('data', (d) ->
        data += d
      )
      response.on('end', () ->
        #console.log "Raven sent"
        if callback
          callback(data)
      )
    )
    req.write(data)
    req.on('error', (e) -> console.log "Connection to Sentry Refused")

module.exports = Raven
