express = require 'express'
router = express.Router()
keys = require '../keys.json'
session = require('express-session')
crypto = require('crypto')
uuid = require 'node-uuid'

router.get('/', (req, res, next) ->
  if req.user
    res.redirect('/canary/dashboard/home')
  else
    res.redirect('/loginflow/')
)

router.get('/home', (req, res) ->

)