express      = require 'express'
session      = require 'express-session'
path         = require 'path'
favicon      = require 'static-favicon'
logger       = require 'morgan'
cookieParser = require 'cookie-parser'
bodyParser   = require 'body-parser'

URL          = require 'url'

passport     = require 'passport'

RedisStore =  require('connect-redis')(session);

use_secure_settings = process.env.USE_SSL is '1'
sessionOptions =
  secret: process.env.EXPRESS_SESSION_SECRET or 'keyboard cat'
  resave: false
  saveUninitialized: true
  name: 'protected_s3.sid'
  proxy: use_secure_settings
  cookie:
    maxAge: 30 * 24 * 60 * 60 * 1000,          # 30 days
    secure: if use_secure_settings then true else null,
    # domain: 'localhost'


if process.env.USE_REDIS_SESSION is '1'
    rdu = require('redis-url')
    rdu.debug_mode = true
    redisURL = rdu.connect(process.env.REDIS_URL)
    redisURL.on 'ready', ->
        console.log 'REDIS -> emit: READY'
    redisURL.on 'connect', ->
        console.log 'REDIS -> emit: CONNECT'
        # redisURL.flushdb()

    rd = URL.parse process.env.REDIS_URL

    options =
        # url: process.env.REDIS_URL
        debug_mode: true
        host: redisURL.hostname
        port: redisURL.port
        # port: parseInt(redisURL.port, 10)
        pass: redisURL.passport
        # pass: rd.auth.split(':')[1]
    sessionOptions.store = new RedisStore(options)
    redisURL.debug_mode = true


app = express()

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
app.use (req, res, next) ->
    console.log JSON.stringify {user: req.session?.user, id: req.session?.id}
    next()
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

if process.env.USE_SSL is '1'
    app.set('trust proxy', 1)

module.exports = app
