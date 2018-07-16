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


module.exports = APIUtilities