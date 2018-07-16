APIConstants = require './APIConstants.coffee'

class Pagination

  constructor: () ->


  paginate: (endpoint, items, total, offset, limit) ->
    next_page = undefined
    prev_page = undefined
    limit = parseInt(limit) || 20
    offset = parseInt(offset) || 0
    if limit < 1
      limit = 1
    if total > (limit + offset) then next_page = APIConstants.baseUrl+endpoint+"?limit="+limit+"&offset="+(offset+limit)
    bk = if ((offset - limit) < 0) then 0 else (offset - limit)
    if offset > 0 then prev_page = APIConstants.baseUrl+endpoint+"?limit="+limit+"&offset="+bk
    if items.length > limit
      items = items.slice(offset,(offset + limit))
    response = {
      items: items
      limit: limit
      offset: offset
      total: total
      next: next_page
      prev: prev_page
    }
    return response

module.exports = Pagination