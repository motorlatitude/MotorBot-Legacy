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
  millisecondsToStr: (milliseconds) ->
    numberEnding = (number) ->
      if number > 1 then 's' else ''
    temp = Math.floor(milliseconds / 1000)
    years = Math.floor(temp / 31536000)
    if years
      return years + ' year' + numberEnding(years)
    days = Math.floor((temp %= 31536000) / 86400)
    if days
      return days + ' day' + numberEnding(days)
    hours = Math.floor((temp %= 86400) / 3600)
    if hours
      return hours + ' hour' + numberEnding(hours)
    minutes = Math.floor((temp %= 3600) / 60)
    if minutes
      return minutes + ' minute' + numberEnding(minutes)
    seconds = temp % 60
    if seconds
      return seconds + ' second' + numberEnding(seconds)
    return 'less than a second'
  db: null
}

module.exports = globals
