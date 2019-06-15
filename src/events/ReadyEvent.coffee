
class ReadyEvent

  constructor: (@Client, @Logger) ->
    @Logger.write("Ready!")

module.exports = ReadyEvent