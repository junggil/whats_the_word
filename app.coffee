express = require 'express'
request = require 'request'
socketio = require 'socket.io'
app = express.createServer()
io = socketio.listen(app)

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
get_random_code = () -> Math.floor(Math.random() * 10000)

#Socket.io
io.sockets.on 'connection', (socket) =>
    socket.on 'playlist add', (data) =>
        socket.broadcast.emit 'playlist add', data
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

#Routes
app.get '/view', (req, res) =>
    global.tv_code = get_random_code()
    res.render('game', {
        code: tv_code
    })

app.get '/user/list', (req, res) =>
    res.json (nickname for nickname of devices)

app.listen 3000, () =>
  console.log "Express server listening on port %d in %s mode", app.address().port, app.settings.env
