// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
const express      = require('express');
const session      = require('express-session');
const path         = require('path');
const favicon      = require('static-favicon');
const logger       = require('morgan');
const cookieParser = require('cookie-parser');
const bodyParser   = require('body-parser');
const passport     = require('passport');


const use_secure_cookie = (process.env.USE_SSL === '1') && (process.env.USE_SECURE_COOKIE === '1');
const sessionOptions = {
    secret: process.env.EXPRESS_SESSION_SECRET || 'keyboard cat',
    resave: false,
    saveUninitialized: false,
    name: 'protected_s3.sid',
    cookie: {
        maxAge: 30 * 24 * 60 * 60 * 1000,          // 30 days
        secure: use_secure_cookie
    }
};

if ((process.env.USE_REDIS_SESSION === '1') && process.env.REDIS_URL) {
    let redisClient = require('redis-url').connect(process.env.REDIS_URL);
    redisClient.on('error', err => console.error("REDIS -> emit: ERROR", err));
    const options = {client: redisClient};
    const RedisStore =  require('connect-redis')(session);
    sessionOptions.store = new RedisStore(options);

    process.on('SIGTERM', function() {
        redisClient.quit();
        redisClient.unref();
        redisClient = null;
    });
}


const app = express();

if (use_secure_cookie) {
  app.set('trust proxy', 1);
}

app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'pug');

app.use(favicon());
app.use(require('stylus').middleware(path.join(__dirname, 'public')));
app.use(express.static(path.join(__dirname, 'public')));
app.use(logger('dev'));
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(cookieParser());
app.use(session(sessionOptions));
app.use(passport.initialize());
app.use(passport.session());

const routes       = require('./routes/index');
const buckets      = require('./routes/buckets');

app.use('/', routes);
app.use('/', buckets);

app.use(function(req, res, next) {
    const err = new Error('Not Found');
    err.status = 404;
    return next(err);
});

if (app.get('env') === 'development') {
    app.use(function(err, req, res, next) {
        res.status(err.status || 500);
        return res.render('error', {
            message: err.message,
            error: err
        }
        );
    });
}

// production error handler
// no stacktraces leaked to user
// but it is printed into console
app.use(function(err, req, res, next) {
    console.error(`PROTECTED_S3_ERROR Uncaught error '${(err != null ? err.message : undefined)}': `, err);
    res.status(err.status || 500);
    return res.render('error', {
        message: err.message,
        error: {}
    });});

if (!process.env.BUCKETS) {
    console.error("Please set BUCKETS environment variable, otherwise this app has no sense.");
}

module.exports = app;
