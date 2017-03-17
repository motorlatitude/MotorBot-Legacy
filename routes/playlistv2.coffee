express = require 'express'
router = express.Router()
keys = require '../keys.json'
session = require('express-session')
crypto = require('crypto')
uuid = require 'node-uuid'

router.get('/playlist', (req, res) ->
  sess = req.session
  if req.user
    userInChannel = false
    if req.user.guilds
      for guild in req.user.guilds
        if guild.id == "130734377066954752" then userInChannel = true
    if userInChannel
      res.render('playlist',{user: req.user})
    else
      res.end("Sorry, not in valid guild :(")
  else
    res.redirect('/loginflow/')
)

router.get('/views/:view/:param?', (req, res) ->
  sess = req.session
  if req.user
    userInChannel = false
    if req.user.guilds
      for guild in req.user.guilds
        if guild.id == "130734377066954752" then userInChannel = true
    if userInChannel
      if req.params.view
        if req.params.view == "playlists" && req.params.param
          res.render("playlistView",{user: req.user, playlistId: req.params.param})
        else if req.params.view == "playlists"
          res.render("playlists",{user: req.user})
        else
          res.render(req.params.view,{user: req.user})
      else
        res.end("You seem lost m9")
    else
      res.end("Sorry, not in valid guild :(")
  else
    res.redirect('/loginflow/')
)

router.get('/dashboard/:view/:param?', (req, res) ->
  sess = req.session
  if req.user
    userInChannel = false
    if req.user.guilds
      for guild in req.user.guilds
        if guild.id == "130734377066954752" then userInChannel = true
    if userInChannel
      if req.params.view == "playlists"
        if req.params.param
          res.render('layout',{user: req.user, view: 'playlists', param: req.params.param})
        else
          res.render('layout',{user: req.user, view: 'playlists', param: undefined})
      else if req.params.view == "home"
        res.render('layout',{user: req.user, view: 'home', param: undefined})
      else if req.params.view == "queue"
        res.render('layout',{user: req.user, view: 'queue', param: undefined})
      else if req.params.view == "library"
        res.render('library',{user: req.user, view: 'library', param: undefined})
      else if req.params.view == "account"
        res.render('layout',{user: req.user, view: 'account', param: undefined})
      else if req.params.view == "connections"
        res.render('layout',{user: req.user, view: 'connections', param: undefined})
      else
        res.render('layout',{user: req.user, view: 'home', param: undefined})
    else
      res.end("Sorry, not in valid guild :(")
  else
    res.redirect('/loginflow/')
)

router.get('/', (req, res, next) ->
  if req.user
    res.redirect('/dashboard/home')
  else
    res.redirect('/loginflow/')
)

module.exports = router
