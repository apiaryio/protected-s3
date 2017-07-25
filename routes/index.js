// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
const express = require('express');
const mimelib = require('mimelib');
const crypto = require('crypto');
const passport = require('passport');
const GoogleStrategy = require('passport-google-oauth').OAuth2Strategy;
const OracleIDCSStrategy = require('@apiaryio/passport-oauth2-idcs');

const router = express.Router();

const {ensureLoggedIn} = require('connect-ensure-login');

const debug = require('debug')('routes');

const use_redis_store = process.env.USE_REDIS_SESSION === '1';

const PROTOCOL = process.env.USE_SSL === '1' ? 'https' : 'http';
const PORT = process.env.APP_PORT ? `:${process.env.APP_PORT}` : '';
const DOMAIN = `${PROTOCOL}://${process.env.DOMAIN || 'localhost'}${PORT}`


const USE_GOOGLE_SSO = !!parseInt(process.env.USE_GOOGLE_SSO, 10);
const USE_ORACLE_SSO = !!parseInt(process.env.USE_ORACLE_SSO, 10);

/*
 * In-memory user database store. Such web scales, very wow.
 */
const USERS = {};

serializeUser = (user, done) => done(null, user.id);
deserializeUser = (id, done) => {
  if (use_redis_store) {
    return done(null, id);
  } else {
    if (!USERS[id]) {
      return done(new Error("Cannot find user", id));
    } else {
      return done(null, USERS[id]);
    }
  }
};

passport.serializeUser(serializeUser);
passport.deserializeUser(deserializeUser);

oAuth2Callback = (accessToken, refreshToken, profile, done) => {
  debug('oAuth2Callback', { accessToken, refreshToken, profile });

  let user;
  const ALLOWED_DOMAINS = (Array.from((process.env.ALLOWED_DOMAINS != null ? process.env.ALLOWED_DOMAINS.split(',') : undefined) || []).map((i) => i.trim()));

  if (!ALLOWED_DOMAINS.length && (process.env.NODE_ENV === 'production')) {
    return done(new Error("ALLOWED_DOMAINS environment variable must be configured for production environment"));
  } else {
    user = {id: profile.id};
  }

  if (!use_redis_store) {
    if (user) {
      USERS[user.id] = user;
    }
    debug('Authenticated - saving to MemStore', { user });
  } else {
    debug('Authenticated - saving to RedisStore.', { user });
  }

  return done(null, user);
}

if (USE_GOOGLE_SSO) {
  // Configure google Strategy
  const strategy = new GoogleStrategy({
      clientID:     process.env.GOOGLE_CLIENT_ID,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET,
      callbackURL: `${DOMAIN}/auth/google/return`,
    }
      // realm:     process.env.GOOGLE_REALM      or "http://localhost:#{process.env.PORT or 3000}/"
      // returnURL: process.env.GOOGLE_RETURN_URL or "http://localhost:#{process.env.PORT or 3000}/auth/google/return"
    , oAuth2Callback);

  passport.use(strategy);

  // Routes
  router.get('/auth/google',
    passport.authenticate('google', {
      scope: 'openid email',
      hostedDomain: process.env.ALLOWED_DOMAINS || 'any'
    })
  );

  router.get('/auth/google/return',
    passport.authenticate('google', {
      scope: 'openid email',
      successReturnToOrRedirect: '/buckets/',
      failureRedirect: '/'
    })
  );
}


if (USE_ORACLE_SSO) {
  const ORACLE_BASE_URL = process.env.ORACLE_BASE_URL;
  const ORACLE_CLIENT_ID = process.env.ORACLE_CLIENT_ID;
  const ORACLE_CLIENT_SECRET = process.env.ORACLE_CLIENT_SECRET;

  const oracleIdcsStrategy = new OracleIDCSStrategy({
    tenantBaseURL: ORACLE_BASE_URL,
    clientID: ORACLE_CLIENT_ID,
    clientSecret: ORACLE_CLIENT_SECRET,
    callbackURL: `${DOMAIN}/auth/oracle/return`,
  }, oAuth2Callback);

  passport.use(oracleIdcsStrategy);

  router.get('/auth/oracle', passport.authenticate('idcs'));
  router.get('/auth/oracle/return', passport.authenticate('idcs', {
    successReturnToOrRedirect: '/buckets/',
    failureRedirect: '/',
  }));
}

router.get('/', ensureLoggedIn('/index'), (req, res) => res.redirect('/buckets/'));
router.get('/index', (req, res) =>
  res.render('index', {
    title: 'Protected S3 bucket',
    domain: process.env.ALLOWED_DOMAINS || 'any',
    useGoogleSso: USE_GOOGLE_SSO,
    useOracleSso: USE_ORACLE_SSO,
  })
);

module.exports = router;
