express      = require 'express'
session      = require 'express-session'
path         = require 'path'
favicon      = require 'static-favicon'
logger       = require 'morgan'
cookieParser = require 'cookie-parser'
bodyParser   = require 'body-parser'

redis = require 'redis-url/node_modules/redis'

URL          = require 'url'

passport     = require 'passport'

RedisStore =  require('connect-redis')(session);

use_secure_settings = process.env.USE_SSL is '1'

sessionOptions =
  secret: process.env.EXPRESS_SESSION_SECRET or 'keyboard cat'
  resave: false
  saveUninitialized: false
  name: 'protected_s3.sid'
  proxy: use_secure_settings
  cookie:
    maxAge: 30 * 24 * 60 * 60 * 1000          # 30 days
    secure: if use_secure_settings then true else null
    domain: process.env.DOMAIN


if process.env.USE_REDIS_SESSION is '1'
    rdu = require('redis-url')
    redisClient = rdu.connect(process.env.REDIS_URL)
    redisClient.on 'ready', ->
        console.log 'REDIS -> emit: READY'
    redisClient.on 'connect', ->
        console.log 'REDIS -> emit: CONNECT'
    redisClient.on 'disconnect', ->
        console.error 'REDIS -> emit: DISCONNECT'
    redisClient.on 'error', (err) ->
        console.error "REDIS -> emit: ERROR", err

    options = client: redisClient
    sessionOptions.store = new RedisStore(options)
    redisClient.debug_mode = true

    process.on 'SIGTERM', ->
        redisClient.quit()


shutdownInProgress = false
onSigTerm = ->
    if shutdownInProgress
      return
    console.log 'Graceful shutdown ...'
    shutdownInProgress = true
    app.close ->
        setTimeout ->
            process.exit(0)
        , 500


app = express()

# graceful shutdown
process.on 'SIGTERM', onSigTerm

if process.env.USE_SSL is '1'
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
