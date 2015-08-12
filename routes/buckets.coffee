express        = require 'express'

{
  getFile
  #getFiles
} = require '../src/aws'

{ensureLoggedIn}        = require 'connect-ensure-login'

BUCKETS = (i.trim() for i in process.env.BUCKETS.split ',')


router = express.Router()

router.get '/buckets', ensureLoggedIn('/index'), (req, res) ->
  if BUCKETS.length > 1
    res.render 'buckets',
      title:   'List of exposed sites'
      buckets: BUCKETS
  else
    res.redirect '/content/'

returnFile = (bucket) -> (req, res) ->
  fileName = req.params[0] or 'index.html'

  getFile bucket, fileName, (err, awsRes) ->
    if err
      console.error "Cannot retrieve file: ", err
      return res.render 'error',
          message: "Cannot retrieve file: ", err.message
          error: {}
    else
      res.set awsRes.headers
      awsRes.pipe res

router.get '/content/*', ensureLoggedIn('/index'), returnFile BUCKETS[0]

router.get '/buckets/:bucket/*', ensureLoggedIn('/index'), (req, res) ->
  returnFile(req.params.bucket)(req, res)

module.exports = router
