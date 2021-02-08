mask = require 'json-mask'

APIConstants = require './APIConstants.coffee'

class APIUtilities

  constructor: () ->

  #should be ignored, mongo projection is generally slower unless filter for only index fields
  formatFilterForMongo: (filter_query) ->
    result = {}
    if filter_query
      filters = filter_query.toString().split(",")
      for field in filters
        result[field] = 1
    return result

  filterResponse: (data, filter_query) ->
    if filter_query
      return mask(data, filter_query.toString().replace(/\./gmi,"/"))
    else
      return data

  has: (obj, key) ->
    return key.split(".").every((x) ->
      if typeof obj != "object" || obj == null || !x in obj
        return false
      obj = obj[x]
      return true
    )

  convertTimestampToSeconds: (input) ->
    reptms = /^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$/
    hours = 0
    minutes = 0
    seconds = 0

    if reptms.test(input)
      matches = reptms.exec(input)
      if (matches[1]) then hours = Number(matches[1])
      if (matches[2]) then minutes = Number(matches[2])
      if (matches[3]) then seconds = Number(matches[3])

    return hours*60*60+minutes*60+seconds;


module.exports = APIUtilities