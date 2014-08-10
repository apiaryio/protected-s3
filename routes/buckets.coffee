express        = require 'express'

router = express.Router()

isLoggedIn = (req, res, next) ->
  if req.isAuthenticated()
    return next()
  else
    res.redirect('/')



router.get '/buckets', isLoggedIn, (req, res) ->
  res.send 200, 'buckets'




module.exports = router
