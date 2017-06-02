express        = require 'express'
mimelib        = require 'mimelib'
passport       = require 'passport'
GoogleStrategy = require('passport-google-oauth').OAuth2Strategy;
OAuth2Strategy = require('passport-oauth2').Strategy;
crypto         = require 'crypto'

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
googleStrategy = new GoogleStrategy
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

headerMap = {};
headerMap['Authorization'] = 'Basic '+ new Buffer('10af2c810f4f4e07990caa64c4b2ac6a:fbfc67be-5609-4980-a2e0-a0244a4be5b0').toString('base64');

oauth2Strategy = new OAuth2Strategy
    authorizationURL: 'https://apiary.identity.preprod.oraclecloud.com/oauth2/v1/authorize'
    tokenURL: 'https://apiary.identity.preprod.oraclecloud.com/oauth2/v1/token'
    clientID: process.env.IDCS_CLIENT_ID
    clientSecret: process.env.IDCS_CLIENT_SECRET
    callbackURL: "http://localhost:3000/auth/oauth2/return"
    customHeaders: headerMap
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

oauth2Strategy.parseErrorResponse = (body, status) ->
    console.log(body)
    console.log(status)
    return new Error(body)

oauth2Strategy.getOAuthAccessToken = (code, params, callback) ->
  params= params || {};
  codeParam = (params.grant_type == 'refresh_token') ? 'refresh_token' : 'code';
  params[codeParam]= code;

  post_data= querystring.stringify( params );
  post_headers= {
       'Content-Type': 'application/x-www-form-urlencoded'
   };


  this._request("POST", this._getAccessTokenUrl(), post_headers, post_data, null, (error, data, response) ->
    if error
         callback(error);
    else

      try
        results= JSON.parse( data );
      catch e
        results= querystring.parse( data );

      access_token= results["access_token"];
      refresh_token= results["refresh_token"];
      delete results["refresh_token"];
      callback(null, access_token, refresh_token, results);
  );

oauth2Strategy.userProfile = (accessToken, done) ->
    userInfoURL = 'https://apiary.identity.preprod.oraclecloud.com/oauth2/v1/userinfo'
    headers =
        'Authorization': this._oauth2.buildAuthHeader(accessToken)
        'Accept': 'application/json'

    this._oauth2._request 'GET', userInfoURL, headers, "", accessToken, (error, body, response) ->
        if error
            console.log(error)
            done(error)
        else
            profile = JSON.parse(body)
            profile.id = crypto.createHash('md5').update(profile.name).digest('hex');
            done(null, profile)


passport.use googleStrategy
passport.use oauth2Strategy

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
    domain: process.env.ALLOWED_DOMAINS or 'any'

router.get '/auth/google',
    passport.authenticate 'google',
        scope: 'openid email'
        hostedDomain: process.env.ALLOWED_DOMAINS or 'any'

router.get '/auth/google/return',
    passport.authenticate 'google',
        scope: 'openid email'
        successReturnToOrRedirect: '/buckets/'
        failureRedirect: '/'

router.get '/auth/oauth2',
    passport.authenticate 'oauth2',
        scope: 'openid'
        hostedDomain: process.env.ALLOWED_DOMAINS or 'any'

router.get '/auth/oauth2/return',
    passport.authenticate 'oauth2',
        scope: 'openid'
        successReturnToOrRedirect: '/buckets/'
        failureRedirect: '/'

module.exports = router
