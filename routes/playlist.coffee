express = require 'express'
router = express.Router()
ObjectID = require('mongodb').ObjectID
globals = require '../models/globals.coffee'

router.get('/', (req, res, next) ->
  res.render('playlist',{})
)

module.exports = router
