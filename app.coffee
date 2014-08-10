express = require('express')
path = require('path')
favicon = require('static-favicon')
logger = require('morgan')
cookieParser = require('cookie-parser')
bodyParser = require('body-parser')

routes = require('./routes/index')
users = require('./routes/users')

app = express()

app.set('views', path.join(__dirname, 'views'))
app.set('view engine', 'jade')

app.use(favicon())
app.use(logger('dev'))
app.use(bodyParser.json())
app.use(bodyParser.urlencoded())
app.use(cookieParser())
app.use(require('stylus').middleware(path.join(__dirname, 'public')))
app.use(express.static(path.join(__dirname, 'public')))

app.use('/', routes)
app.use('/users', users)

app.use (req, res, next) ->
    err = new Error('Not Found')
    err.status = 404
    next(err)

if (app.get('env') is 'development') 
    app.use (err, req, res, next) ->
        res.status(err.status || 500)
        res.render('error', {
            message: err.message,
            error: err
        })

# production error handler
# no stacktraces leaked to user
app.use (err, req, res, next) ->
    res.status(err.status || 500)
    res.render 'error', 
        message: err.message,
        error: {}


module.exports = app
