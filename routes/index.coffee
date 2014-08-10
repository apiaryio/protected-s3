express        = require 'express'
mimelib        = require 'mimelib'
passport       = require 'passport'
GoogleStrategy = require('passport-google').Strategy;

router = express.Router()


# Configure google login
strategy = new GoogleStrategy
    returnURL: process.env.GOOGLE_RETURN_URL or "http://localhost:#{process.env.PORT or 3000}/auth/google/return"
    realm:     process.env.GOOGLE_REALM      or "http://localhost:#{process.env.PORT or 3000}/"
  , (identifier, profile, done) ->

    ALLOWED_DOMAINS = (i.trim() for i in process.env.ALLOWED_DOMAINS?.split(',') or [])

    if not ALLOWED_DOMAINS.length
      if process.env.NODE_ENV is 'production'
        return done new Error "ALLOWED_DOMAINS environment variable must be configured for production environment"
      else
        user = openId: identifier, id: profile.emails[0].value        
    
    else
      user = false
      for email in profile.emails
        email = mimelib.parseAddresses email
        emailDomain = email[0].address.split('@')[1]

        for domain in ALLOWED_DOMAINS
          if domain is emailDomain
            user = openId: identifier, id: email
            break

    USERS[user.id] = user if user

    done null, user

passport.use strategy




###
# In-memory user database store. Such web scales, very wow. 
### 
USERS = {}


passport.serializeUser (user, done) ->
  done null, user.id


passport.deserializeUser (id, done) ->
  if not USERS[id]
    done new Error "Cannot find user", id
  else
    done null, USERS[id]


router.get '/', (req, res) ->
  res.render 'index', title: 'Protected S3 bucket'

router.get '/auth/google', passport.authenticate 'google'

router.get '/auth/google/return', 
  passport.authenticate 'google',
    successRedirect: '/buckets/'
    failureRedirect: '/'


module.exports = router
