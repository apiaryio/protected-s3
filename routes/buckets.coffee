express        = require 'express'

router = express.Router()

isLoggedIn = (req, res, next) ->
  if req.isAuthenticated()
    return next()
  else
    res.redirect('/')

BUCKETS = (i.trim() for i in process.env.BUCKETS.split ',')

router.get '/', isLoggedIn, (req, res) ->
  res.render 'buckets',
    title:   'List of exposed sites'
    buckets: BUCKETS


module.exports = router
