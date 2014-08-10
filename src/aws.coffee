knox = require 'knox'


getFile = (bucket, fileName, cb) ->
  client = knox.createClient
    key:    process.env.ACCESS_KEY
    secret: process.env.SECRET_KEY
    bucket: bucket

  client.getFile "/#{fileName}", cb

module.exports = {
  getFile
}
