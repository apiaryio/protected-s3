const express        = require('express');

const {
  getFile
  //getFiles
} = require('../src/aws');

const {ensureLoggedIn}        = require('connect-ensure-login');

const BUCKETS = (Array.from(process.env.BUCKETS.split(',')).map((i) => i.trim()));


const router = express.Router();

router.get('/buckets', ensureLoggedIn('/index'), function(req, res) {
  if (BUCKETS.length > 1) {
    return res.render('buckets', {
      title:   'List of exposed sites',
      buckets: BUCKETS
    }
    );
  } else {
    return res.redirect('/content/');
  }
});

const returnFile = bucket => function(req, res) {
  const fileName = req.params[0] || 'index.html';

  return getFile(bucket, fileName, function(err, awsRes) {
    if (err) {
      console.error("Cannot retrieve file: ", err);
      return res.render('error',
          {message: "Cannot retrieve file: "}, err.message,
          {error: {}});
    } else {
      res.set(awsRes.headers);
      return awsRes.pipe(res);
    }
  });
} ;

router.get('/content/*', ensureLoggedIn('/index'), returnFile(BUCKETS[0]));

router.get('/buckets/:bucket/*', ensureLoggedIn('/index'), (req, res) => returnFile(req.params.bucket)(req, res));

module.exports = router;
