globals = {
  dc: null
  convertTimestamp: (input) ->
    reptms = /^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$/
    hours = 0
    minutes = 0
    seconds = 0

    if reptms.test(input)
      matches = reptms.exec(input)
      if (matches[1]) then hours = Number(matches[1])
      if (matches[2]) then minutes = Number(matches[2])
      if (matches[3]) then seconds = Number(matches[3])
      if (minutes < 10) then minutes = "0"+minutes
      if (seconds < 10) then seconds = "0"+seconds
    if hours == 0
      return minutes+":"+seconds
    else
      return hours+":"+minutes+":"+seconds
  db: null
}

module.exports = globals
