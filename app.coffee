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

get_random_code = () -> Math.floor(Math.random() * 10000)
endsWith = (str, suffix) -> str.indexOf(suffix, str.length - suffix.length) != -1
shuffle = (o) ->
    j = x = i = o.length
    while i
      j = parseInt(Math.random() * i)
      x = o[--i]
      o[i] = o[j]
      o[j] = x
    return o

bySortedValue = (obj) ->
    tuples = ([key, obj[key]] for key of obj)
    tuples.sort((a, b) -> if a[1] < b[1] then 1 else if a[1] > b[1] then -1 else 0)

init_quiz = () ->
    fs.readdir('public/images/quiz/', (err, files) ->
        global.quiz_bucket = shuffle(files.filter((filename) -> endsWith(filename, '.jpg')).map((filename) -> filename.split('.')[0]))
        global.quiz_info = {stage:1, quiz:quiz_bucket.pop()}
        global.devices = {}
    )

#Socket.io
io.sockets.on 'connection', (socket) =>
    socket.on 'mobile connect', (data) =>
        if parseInt(data.code) != tv_code
            socket.emit 'connect ack', {success:false, msg:'TV Code is invalid, check again'}
        else if data.nickname of devices
            socket.emit 'connect ack', {success:false, msg:'Nickname is already taken!'}
        else
            devices[data.nickname] = 0
            socket.emit 'connect ack', {success:true}
            socket.broadcast.emit 'update ranking', bySortedValue(devices)[0..2]

#RestAPI
app.get '/quiz/submit', (req, res) =>
    if req.query['answer'] == quiz_info.quiz.toUpperCase()
        global.quiz_info = {stage:quiz_info.stage + 1, quiz:quiz_bucket.pop()}
        devices[req.query['nickname']]++
        io.sockets.emit 'quiz next', {nickname:req.query['nickname']}
        io.sockets.emit 'update trial', {nickname:req.query['nickname'], trial:req.query['answer']}
        io.sockets.emit 'update ranking', bySortedValue(devices)[0..2]
        res.json {success:true}
    else
        res.json {success:false}

app.get '/quiz', (req, res) =>
    res.json quiz_info

#Routes
app.get '/', (req, res) =>
    init_quiz()
    global.tv_code = get_random_code()
    res.render('game', {
        code: tv_code
    })
    console.log tv_code

init_quiz()

app.listen process.env.PORT || 5000, () =>
  console.log "Express server listening on port %d in %s mode", app.address().port, app.settings.env
