express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
keys = require '../keys.json'
request = require('request')
async = require('async')
uid = require('rand-token').uid
path = require 'path'
moment = require 'moment'

# Destiny SQL data
sqlite3 = require('sqlite3').verbose();

###
  DESTINY2 CALLBACK
###

tokens = {}

router.get("/", (req, res) ->
  res.end("Hi")
)

router.get("/callback", (req, res) ->
  authorization_code = req.query.code
  formData = {
    code: authorization_code,
    grant_type: "authorization_code"
  }
  console.log formData
  request({
    url: "https://www.bungie.net/Platform/App/oauth/token/",
    method: "POST",
    json: true,
    form: formData,
    headers: {
      Authorization: "Basic " + Buffer.from(keys.destiny.clientId + ":" + keys.destiny.clientSecret).toString('base64')
    }
  }, (error, httpResponse, body) ->
    if error then console.log error
    console.log JSON.stringify(body)
    if body
      if body.access_token
        tokens.access_token = body.access_token
        tokens.refresh_token = body.refresh_token
        tokens.expires = new Date().getTime() + body.expires_in*1000
        tokens.refresh_expires = new Date().getTime() + body.refresh_expires_in*1000
        res.end("Success")
    else
      console.log "Error retrieving access_token, no body returned"
      res.end("An unknown error occurred retrieving an access_token")
  )
)

getXurData = (req, callbk) ->
  destinyRequestsCollection = req.app.locals.motorbot.database.collection("destinyRequests")
  d = new Date()
  requestTimestamp = d.getTime()
  currentTime_day = d.getDay() #4
  currentTime_hour = d.getUTCHours() # 17
  console.log currentTime_hour
  console.log currentTime_day
  if currentTime_day == 5 && currentTime_hour == 17
    request({
      method: "GET",
      url: "https://www.bungie.net/Platform/Destiny2/4/Profile/4611686018467344163/Character/2305843009301346658/Vendors?components=400,401,402",
      json: true,
      headers: {
        "X-API-Key": keys.destiny.api,
        Authorization: "Bearer "+tokens.access_token
      }
    }, (err, httpResponse, body) ->
      if err then console.log err
      console.log "XurData"
      if body
        if body.Response
          if body.Response.vendors
            body["requestTimestamp"] = requestTimestamp
            destinyRequestsCollection.update({requestTimestamp: requestTimestamp}, body, {upsert: true}, (err, result) ->
              if err then console.log err
              callbk(body)
            )
          else
            console.log "DESTINY_API_ERROR (destiny2.coffee:0x0053): Response did not contain vendor information"
        else
          console.log "DESTINY_API_ERROR (destiny2.coffee:0x0055): Response did not contain a response object"
      else
        console.log "DESTINY_API_ERROR (destiny2.coffee:0x0057): Response did not contain a response body"
    )
  else
    destinyRequestsCollection.find({requestTimestamp: {$gt: requestTimestamp-(3600*1000)}}).toArray((err, results) ->
      if err then console.log err
      if results[0]
        console.log "Found Previous Request: "+results[0].requestTimestamp
        callbk(results[0])
      else
        request({
          method: "GET",
          url: "https://www.bungie.net/Platform/Destiny2/4/Profile/4611686018467344163/Character/2305843009301346658/Vendors?components=400,401,402",
          json: true,
          headers: {
            "X-API-Key": keys.destiny.api,
            Authorization: "Bearer "+tokens.access_token
          }
        }, (err, httpResponse, body) ->
          if err then console.log err
          console.log "XurData"
          if body
            if body.Response
              if body.Response.vendors
                body["requestTimestamp"] = requestTimestamp
                destinyRequestsCollection.update({requestTimestamp: requestTimestamp}, body, {upsert: true}, (err, result) ->
                  if err then console.log err
                  callbk(body)
                )
              else
                console.log "DESTINY_API_ERROR (destiny2.coffee:0x0074): Response did not contain vendor information"
            else
              console.log "DESTINY_API_ERROR (destiny2.coffee:0x0076): Response did not contain a response object"
          else
            console.log "DESTINY_API_ERROR (destiny2.coffee:0x0078): Response did not contain a response body"
        )
    )

analyseXurData = (vendors, req, res, c) ->
  xur_data = vendors.vendors.data["2190858386"]
  destinyCollection = req.app.locals.motorbot.database.collection("destiny")
  if xur_data
    unique_id = Buffer.from(xur_data.nextRefreshDate.toString()).toString("base64")
    destinyCollection.find({id: unique_id}).toArray((err, results) ->
      if err then console.log err
      if results[0]
        if req.query.json
          res.type("json")
          res.send(JSON.stringify(results[0]))
        else
          leavingtimestamp = moment.utc("170000","HHmmss").day(1).unix()*1000;
          available = true
          if leavingtimestamp > results[0].refresh_date
            available = false
          res.render("destiny", {items: results[0], available: available})
        c()
      else
        refresh_date = new Date(xur_data.nextRefreshDate.toString()).getTime()
        xur_items = {
          id: unique_id
          refresh_date: refresh_date,
          categories: {}
          vendor: {}
          vendor_summary: xur_data
          sockets: {}
          perks: {}
          currency_info: {}
        }
        destiny_db = new sqlite3.Database(path.join(__dirname, '../world_sql_content.sqlite'), sqlite3.OPEN_READONLY, (err) ->
          console.log "DESTINY_DB_OPENED"
          if err then console.log "DESTINY_DB_ERROR: "+err
          if xur_data
            xur_item_categories = vendors.categories.data["2190858386"]
            xur_sales = vendors.sales.data["2190858386"].saleItems
            for item_category in xur_item_categories.categories
              xur_items["categories"][item_category.displayCategoryIndex] = {items:{}, detailed_items:{}}
              xur_items["categories"][item_category.displayCategoryIndex] = item_category
            xur_items_org = xur_items
            async.forEach(xur_items_org.categories, (item_cat, callback) ->
              xur_items["categories"][item_cat.displayCategoryIndex]["items"] = {}
              xur_items["categories"][item_cat.displayCategoryIndex]["detailed_items"] = {}
              async.forEach(item_cat.itemIndexes, (item, cb) ->
                item_data = xur_sales[""+item]
                xur_items["categories"][item_cat.displayCategoryIndex]["items"][item_data.itemHash] = xur_sales[""+item]
                #detailed item description
                sql = "SELECT * FROM DestinyInventoryItemDefinition WHERE json LIKE '%\"hash\":"+item_data.itemHash+"%'"
                console.log sql
                destiny_db.get(sql, (err, row) ->
                  if err then console.log err
                  if row
                    #item found return info
                    detailed_item_info = JSON.parse(row.json)
                    xur_items["categories"][item_cat.displayCategoryIndex]["detailed_items"][detailed_item_info.hash] = detailed_item_info
                    console.log detailed_item_info.hash
                    if detailed_item_info.sockets
                      async.parallel([
                        (ca) ->
                          async.forEach(detailed_item_info.sockets.socketEntries, (entry, ck) ->
                            sql = "SELECT * FROM DestinyInventoryItemDefinition WHERE json LIKE '%\"hash\":"+entry.singleInitialItemHash+"%'"
                            console.log sql
                            destiny_db.get(sql, (err, row) ->
                              if err then console.log err
                              if row
                                detailed_socket_info = JSON.parse(row.json)
                                xur_items["sockets"][detailed_socket_info.hash] = detailed_socket_info
                                if detailed_socket_info.perks[0]
                                  sql = "SELECT * FROM DestinySandboxPerkDefinition WHERE json LIKE '%"+detailed_socket_info.perks[0].perkHash+"%'"
                                  console.log sql
                                  destiny_db.get(sql, (err, row) ->
                                    if err then console.log err
                                    if row
                                      detailed_perk_info = JSON.parse(row.json)
                                      xur_items["perks"][detailed_perk_info.hash] = detailed_perk_info
                                      ck()
                                    else
                                      console.log "DESTINY_SOCKET_PERK_NOT_FOUND"
                                      ck()
                                  )
                                else
                                  console.log "DESTINY_SOCKET_HAS_NO_PERK"
                                  ck()
                              else
                                ck()
                            )
                          , (err) ->
                            ca()
                          )
                      , (cc) ->
                          costs = xur_items["categories"][item_cat.displayCategoryIndex]["items"][item_data.itemHash].costs
                          async.forEach(costs, (cost_type, ckk) ->
                            sql = "SELECT * FROM DestinyInventoryItemDefinition WHERE json LIKE '%\"hash\":"+cost_type.itemHash+"%'"
                            console.log sql
                            destiny_db.get(sql, (err, row) ->
                              if err then console.log err
                              if row
                                detailed_currency_info = JSON.parse(row.json)
                                xur_items["currency_info"][detailed_currency_info.hash] = detailed_currency_info
                              ckk()
                            )
                          , (err) ->
                            cc()
                          )
                      ], (err) ->
                        cb()
                      )

                    else
                      console.log "DESTINY_NO_SOCKETS: Couldn't find a destiny item with that hash"
                      cb()
                  else
                    #no item found, wtf?
                    console.log "DESTINY_ITEM_NOT_FOUND: Couldn't find a destiny item with that hash"
                    cb()

                )
              , (err) ->
                callback(err)
              )
            , (err) ->
              if err then console.log err
              sql = "SELECT * FROM DestinyVendorDefinition WHERE json LIKE '%\"hash\":2190858386%'"
              destiny_db.get(sql, (err, row) ->
                if err then console.log err
                if row
                  vendor_data = row.json
                  vendor_data = vendor_data.replace(/BungieNet\.Engine\.Contract\.Destiny\.World\.Definitions\.IDestinyDisplayDefinition\.displayProperties/gmi,"BungieNet_Engine_Contract_Destiny_World_Definitions_IDestinyDisplayDefinition_displayProperties")
                  detailed_vendor_info = JSON.parse(vendor_data)
                  xur_items["vendor"] = detailed_vendor_info
                  #console.log xur_items
                  destinyCollection.update({id: unique_id}, xur_items, {upsert: true}, (err, result) ->
                    if err then console.log err
                    if req.query.json
                      res.type("json")
                      res.send(JSON.stringify(xur_items))
                    else
                      res.render("destiny", {items: xur_items, available: true})
                    c()
                  )
              )
            )
          else
            console.log "XurItems"
            if req.query.json
              res.type("json")
              res.send(JSON.stringify(xur_items))
            else
              res.render("destiny", {items: {}, available: false})
            c()
        );
    )
  else
    destinyCollection.find({refresh_date: {$gt: new Date().getTime()}}).toArray((err, results) ->
      if err then console.log err
      if results[0]
        if req.query.json
          res.type("json")
          res.send(JSON.stringify({previous_inventory: results[0]}))
        else
          res.render("destiny", {items: results[0], available: false})
      else
        if req.query.json
          res.type("json")
          res.send(JSON.stringify({items: {}, available: false}))
        else
          res.render("destiny", {items: {}, available: false})
      c()
    )



router.get("/Xur", (req, res) ->
  #return current items that xur is selling
  timestamp = new Date().getTime()
  if timestamp >= tokens.expires && timestamp <= tokens.refresh_expires
    #need to refresh token using refresh_token
    console.log "//REFRESHING DESTINY TOKENS"
    formData = {
      refresh_token: tokens.refresh_token,
      grant_type: "refresh_token"
    }
    console.log formData
    request({
      url: "https://www.bungie.net/Platform/App/oauth/token/",
      method: "POST",
      json: true,
      form: formData,
      headers: {
        Authorization: "Basic " + Buffer.from(keys.destiny.clientId + ":" + keys.destiny.clientSecret).toString('base64')
      }
    }, (error, httpResponse, body) ->
      if error then console.log error
      console.log body
      if body
        if body.access_token
          tokens.access_token = body.access_token
          tokens.refresh_token = body.refresh_token
          tokens.expires = new Date().getTime() + body.expires_in*1000
          tokens.refresh_expires = new Date().getTime() + body.refresh_expires_in*1000
          getXurData(req, (data) ->
            if data.Response
              if data.Response.vendors
                analyseXurData(data.Response, req, res, () ->
                  console.log "done"
                )
          )
      else
        console.log "Error retrieving access_token, no body returned"
    )
  else if timestamp < tokens.expires
    getXurData(req, (data) ->
      if data.Response
        if data.Response.vendors
          analyseXurData(data.Response, req, res, () ->
            console.log "done"
          )
    )
  else
    # We're screwed, need new tokens
    console.log "Can no longer get Xur items as a re-authorisation is required"


)

module.exports = router