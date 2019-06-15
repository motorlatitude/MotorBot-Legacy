express = require 'express'
router = express.Router()

router.get('/views/:view/:param?', (req, res) ->
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
        else if req.params.view == "account"
          if req.params.param && req.params.param != "undefined"
            res.render("account/"+req.params.param,{user: req.user})
          else
            res.render("account",{user: req.user})
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
  if req.user
    userInChannel = false
    if req.user.guilds
      for guild in req.user.guilds
        if guild.id == "130734377066954752" then userInChannel = true
    if userInChannel
        res.render('layout',{user: req.user, view: req.params.view, param: req.params.param})
    else
      res.end("Sorry, not in valid guild :(")
  else
    res.redirect('/loginflow/')
)

router.get('/', (req, res, next) ->
  if req.user
    res.redirect('/dashboard/browse')
  else
    res.redirect('/loginflow/')
)

module.exports = router
