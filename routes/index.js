const express        = require('express');
const mimelib        = require('mimelib');
const passport       = require('passport');
const GoogleStrategy = require('passport-google-oauth').OAuth2Strategy;

const router = express.Router();

const {ensureLoggedIn}    = require('connect-ensure-login');

const use_redis_store = process.env.USE_REDIS_SESSION === '1';


/*
 * In-memory user database store. Such web scales, very wow.
 */
let USERS = {};

// Configure google login
const protocol = process.env.USE_SSL === '1' ? 'https' : 'http';
const port = process.env.APP_PORT ? `:${process.env.APP_PORT}` : "";
const strategy = new GoogleStrategy({
    clientID:     process.env.GOOGLE_CLIENT_ID,
    clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    callbackURL: `${protocol}://${process.env.DOMAIN || "127.0.0.1"}${port}/auth/google/return`
  }
    // realm:     process.env.GOOGLE_REALM      or "http://localhost:#{process.env.PORT or 3000}/"
    // returnURL: process.env.GOOGLE_RETURN_URL or "http://localhost:#{process.env.PORT or 3000}/auth/google/return"
  , function(accessToken, refreshToken, profile, done) {

    let user;
    const ALLOWED_DOMAINS = (Array.from((process.env.ALLOWED_DOMAINS != null ? process.env.ALLOWED_DOMAINS.split(',') : undefined) || []).map((i) => i.trim()));

    if (!ALLOWED_DOMAINS.length && (process.env.NODE_ENV === 'production')) {
        return done(new Error("ALLOWED_DOMAINS environment variable must be configured for production environment"));
    } else {
        user = {id: profile.id};
      }

    if (!use_redis_store) {
      if (user) { USERS[user.id] = user; }
      console.log('Authenticated - saving to MemStore.', user);
    } else {
      console.log('Authenticated - saving to RedisStore.', user);
    }

    return done(null, user);
});

passport.use(strategy);




/*
 * In-memory user database store. Such web scales, very wow.
 * This is only used if USE_REDIS_SESSION is set to 0.
 */
USERS = {};


passport.serializeUser((user, done) => done(null, user.id));


passport.deserializeUser(function(id, done) {
  if (use_redis_store) {
    return done(null, id);
  } else {
    if (!USERS[id]) {
      return done(new Error("Cannot find user", id));
    } else {
      return done(null, USERS[id]);
    }
  }});


router.get('/', ensureLoggedIn('/index'), (req, res) => res.redirect('/buckets/'));

router.get('/index', (req, res) =>
  res.render('index', {
    title: 'Protected S3 bucket',
    domain: process.env.ALLOWED_DOMAINS || 'any'
  }
  )
);

router.get('/auth/google',
  passport.authenticate('google', {
    scope: 'openid email',
    hostedDomain: process.env.ALLOWED_DOMAINS || 'any'
  }
  )
);

router.get('/auth/google/return',
  passport.authenticate('google', {
    scope: 'openid email',
    successReturnToOrRedirect: '/buckets/',
    failureRedirect: '/'
  }
  )
);


module.exports = router;
