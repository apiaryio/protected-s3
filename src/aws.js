knox = require 'knox'

clients = {}

getFile = (bucket, fileName, cb) ->
  clients[bucket] ?= knox.createClient
    key:    process.env.ACCESS_KEY
    secret: process.env.SECRET_KEY
    bucket: bucket

  clients[bucket].getFile "/#{fileName}", cb

module.exports = {
  getFile
}
