express        = require 'express'
mimelib        = require 'mimelib'
passport       = require 'passport'
GoogleStrategy = require('passport-google-oauth').OAuth2Strategy;

router = express.Router()

{ensureLoggedIn}    = require 'connect-ensure-login'

use_redis_store = process.env.USE_REDIS_SESSION is '1'


###
# In-memory user database store. Such web scales, very wow.
###
USERS = {}

# Configure google login
protocol = if process.env.USE_SSL is '1' then 'https' else 'http'
port = if process.env.APP_PORT then ":" + process.env.APP_PORT else ""
strategy = new GoogleStrategy
    clientID:     process.env.GOOGLE_CLIENT_ID
    clientSecret: process.env.GOOGLE_CLIENT_SECRET
    callbackURL: "#{protocol}://#{process.env.DOMAIN or "127.0.0.1"}#{port}/auth/google/return"
    # realm:     process.env.GOOGLE_REALM      or "http://localhost:#{process.env.PORT or 3000}/"
    # returnURL: process.env.GOOGLE_RETURN_URL or "http://localhost:#{process.env.PORT or 3000}/auth/google/return"
  , (accessToken, refreshToken, profile, done) ->

    ALLOWED_DOMAINS = (i.trim() for i in process.env.ALLOWED_DOMAINS?.split(',') or [])

    if not ALLOWED_DOMAINS.length and process.env.NODE_ENV is 'production'
        return done new Error "ALLOWED_DOMAINS environment variable must be configured for production environment"
    else
        user = id: profile.id

    if not use_redis_store
      USERS[user.id] = user if user
      console.log 'Authenticated - saving to MemStore.', user
    else
      console.log 'Authenticated - saving to RedisStore.', user

    done null, user

passport.use strategy




###
# In-memory user database store. Such web scales, very wow.
# This is only used if USE_REDIS_SESSION is set to 0.
###
USERS = {}


passport.serializeUser (user, done) ->
  done null, user.id


passport.deserializeUser (id, done) ->
  if use_redis_store
    done null, id
  else
    if not USERS[id]
      done new Error "Cannot find user", id
    else
      done null, USERS[id]


router.get '/', ensureLoggedIn('/index'), (req, res) ->
  res.redirect('/buckets/')

router.get '/index', (req, res) ->
  res.render 'index',
    title: 'Protected S3 bucket'
    domain: if process.env.ALLOWED_DOMAINS then process.env.ALLOWED_DOMAINS else 'any'

router.get '/auth/google',
  passport.authenticate 'google',
    scope: 'openid email'
    hostedDomain: process.env.ALLOWED_DOMAINS

router.get '/auth/google/return',
  passport.authenticate 'google',
    scope: 'openid email'
    successReturnToOrRedirect: '/buckets/'
    failureRedirect: '/'


module.exports = router
