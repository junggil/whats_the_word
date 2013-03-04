express = require 'express'
socketio = require 'socket.io'
fs = require 'fs'

app = express.createServer()

io = socketio.listen(app)
io.configure () =>
    io.set "transports", ["xhr-polling"]
    io.set "polling duration", 10

app.configure =>
  app.set 'views', __dirname + '/views'
  app.set 'view engine', 'jade'
  app.set 'view options', {layout:false}
  app.set 'jsonp callback', true
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use app.router
  app.use express.static(__dirname + '/public')

app.configure 'development', () =>
  app.use express.errorHandler({ dumpExceptions: true, showStack: true })

app.configure 'production', () =>
  app.use express.errorHandler()


global.tv_code = 2848
global.devices = {}
global.quiz_bucket = []
global.quiz_info = {}
load_quiz_bucket = (path) ->
    fs.readdirSync(path).filter((filename) ->
        endsWith = (str, suffix) ->
            str.indexOf(suffix, str.length - suffix.length) != -1
        fs.statSync(path + filename).isFile() and endsWith(filename, '.png')
    ).map((filename) -> filename.split('.')[0])
get_random_code = () -> Math.floor(Math.random() * 10000)
pick_new_quiz = () -> quiz_bucket.splice(Math.floor(Math.random() * quiz_bucket.length), 1)

#Socket.io
io.sockets.on 'connection', (socket) =>
    socket.on 'mobile connect', (data) =>
        if parseInt(data.code) != tv_code
            socket.emit 'connect ack', {success:false, msg:'TV Code is invalid, check again'}
        else if data.nickname of devices
            socket.emit 'connect ack', {success:false, msg:'Nickname is already taken!'}
        else
            devices[data.nickname] = socket
            socket.emit 'connect ack', {success:true}
    socket.on 'mobile chat', (data) =>
        socket.broadcast.emit 'chat message', data
    socket.on 'disconnect', () =>
        for key of devices
            if devices[key] == socket
                delete devices[key]
                break

#RestAPI
app.get '/quiz/next', (req, res) =>
    global.quiz_info = {stage:quiz_info.stage + 1, quiz:pick_new_quiz()}
    io.sockets.emit 'quiz next notification'

app.get '/quiz', (req, res) =>
    res.json quiz_info

#Routes
app.get '/', (req, res) =>
    global.quiz_bucket = load_quiz_bucket 'public/images/quiz/'
    global.quiz_info = {stage:1, quiz:pick_new_quiz()}
    global.tv_code = get_random_code()
    res.render('game', {
        code: tv_code
    })
    console.log tv_code

app.listen process.env.PORT || 5000, () =>
  console.log "Express server listening on port %d in %s mode", app.address().port, app.settings.env
