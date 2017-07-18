const knox = require('knox');

const clients = {};

const getFile = function(bucket, fileName, cb) {
  if (clients[bucket] == null) { clients[bucket] = knox.createClient({
    key:    process.env.ACCESS_KEY,
    secret: process.env.SECRET_KEY,
    bucket
  }); }

  return clients[bucket].getFile(`/${fileName}`, cb);
};

module.exports = {
  getFile
};
