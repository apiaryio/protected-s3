express      = require 'express'
session      = require 'express-session'
path         = require 'path'
favicon      = require 'static-favicon'
logger       = require 'morgan'
cookieParser = require 'cookie-parser'
bodyParser   = require 'body-parser'
passport     = require 'passport'


use_secure_cookie = process.env.USE_SSL is '1' and process.env.USE_SECURE_COOKIE is '1'
sessionOptions =
    secret: process.env.EXPRESS_SESSION_SECRET or 'keyboard cat'
    resave: false
    saveUninitialized: false
    name: 'protected_s3.sid'
    cookie:
        maxAge: 30 * 24 * 60 * 60 * 1000          # 30 days
        secure: use_secure_cookie
        # domain: if process.env.DOMAIN == 'localhost' then null else process.env.DOMAIN

if process.env.USE_REDIS_SESSION is '1' and process.env.REDIS_URL
    redisClient = require('redis-url').connect(process.env.REDIS_URL)
    redisClient.on 'error', (err) ->
        console.log "REDIS -> emit: ERROR", err
    options = client: redisClient
    RedisStore =  require('connect-redis')(session);
    sessionOptions.store = new RedisStore(options)

    process.on 'SIGTERM', ->
        redisClient.quit()
        redisClient.unref()
        redisClient = null
        return


app = express()

if use_secure_cookie
  app.set('trust proxy', 1)

app.set('views', path.join(__dirname, 'views'))
app.set('view engine', 'jade')

app.use(favicon())
app.use(require('stylus').middleware(path.join(__dirname, 'public')))
app.use(express.static(path.join(__dirname, 'public')))
app.use(logger('dev'))
app.use(bodyParser.json())
app.use(bodyParser.urlencoded())
app.use(cookieParser())
app.use(session(sessionOptions))
app.use(passport.initialize())
app.use(passport.session())

routes       = require './routes/index'
buckets      = require './routes/buckets'

app.use('/', routes)
app.use('/', buckets)

app.use (req, res, next) ->
    err = new Error('Not Found')
    err.status = 404
    next(err)

if app.get('env') is 'development'
    app.use (err, req, res, next) ->
        res.status err.status or 500
        res.render 'error',
            message: err.message,
            error: err

# production error handler
# no stacktraces leaked to user
# but it is printed into console
app.use (err, req, res, next) ->
    console.error "PROTECTED_S3_ERROR Uncaught error '#{err?.message}': ", err
    res.status err.status or 500
    res.render 'error',
        message: err.message,
        error: {}

if not process.env.BUCKETS
    console.error "Please set BUCKETS environment variable, otherwise this app has no sense."

module.exports = app
