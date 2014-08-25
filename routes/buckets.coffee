express        = require 'express'

{
  getFile
  #getFiles
} = require '../src/aws'

cel        = require ('connect-ensure-login')

BUCKETS = (i.trim() for i in process.env.BUCKETS.split ',')


router = express.Router()

router.get '/buckets', cel.ensureLoggedIn('/'), (req, res) ->
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
      awsRes.pipe res

router.get '/content/*', cel.ensureLoggedIn('/'), returnFile BUCKETS[0]

router.get '/buckets/:bucket/*', cel.ensureLoggedIn('/'), (req, res) ->
  returnFile(req.params.bucket)(req, res)

module.exports = router
