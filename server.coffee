# https://github.com/tristandunn/node-hoptoad-notifier

require('joose')
require('joosex-namespace-depended')
require('hash')
Http = require('http')
Express = require('express')
IO = require('socket.io')
Jade = require('jade')
Helpers = require('./helpers')

app = Express.createServer()

app.configure ->
  app.use(Express.staticProvider(__dirname + '/public'))
  app.set('view engine', 'jade')

app.get '/', (req, res) ->
  res.render('index', { layout: false })

app.get /\/go|bookmarklet\.js/, (req, res) ->
  res.contentType('text/javascript')
  if Helpers.verifyParams(req)
    res.render('bookmarklet.ejs', {
      layout: false,
      locals: {
        to: req.param('to')
      }
    })
  else
    res.send("alert('Invalid request. Missing query params. Try making your bookmarklet again.');")

app.listen(9090)

socket = IO.listen(app)
socket.on 'connection', (client) ->
  client.on 'message', (data) ->
    json = JSON.parse(data)
    Helpers.processSocketIO(json.url, json.to, client)