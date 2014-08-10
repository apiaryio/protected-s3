express        = require 'express'
passport       = require 'passport'
GoogleStrategy = require('passport-google').Strategy;

router = express.Router()


# Configure google login
strategy = new GoogleStrategy
    returnURL: process.env.GOOGLE_RETURN_URL or "http://localhost:#{process.env.PORT or 3000}/auth/google/return"
    realm:     process.env.GOOGLE_REALM      or "http://localhost:#{process.env.PORT or 3000}/"
  , (identifier, profile, done) ->
    user = openId: identifier, id: profile.emails[0].value
    USERS[user.id] = user

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
    console.log 'AUTHENTICATED'
    done null, USERS[id]


router.get '/', (req, res) ->
  res.render 'index', title: 'Protected S3 bucket'

router.get '/auth/google', passport.authenticate 'google'

router.get '/auth/google/return', 
  passport.authenticate 'google',
    successRedirect: '/buckets'
    failureRedirect: '/login'


module.exports = router
