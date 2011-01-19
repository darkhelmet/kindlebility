# https://github.com/tristandunn/node-hoptoad-notifier

require('joose')
require('joosex-namespace-depended')
require('hash')
Url = require('url')
Http = require('http')
Query = require('querystring')
Sys = require('sys')
Readability = require('./readability/lib/readability')
Spawn = require('child_process').spawn
Request = require('request')
Express = require('express')
IO = require('socket.io')
Jade = require('jade')
Helpers = require('./helpers')
Postmark = 'http://api.postmarkapp.com/email'
UserAgent = "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_5; en-US) AppleWebKit/534.10 (KHTML, like Gecko) Chrome/8.0.552.215 Safari/534.10"

verifyParams = (req) ->
  url = Url.parse(req.url)
  return false unless url.query?
  query = Query.parse(url.query)
  return false unless query.u? && query.to?
  return true

app = Express.createServer()

app.configure ->
  app.use(Express.staticProvider(__dirname + '/public'))
  app.set('view engine', 'jade')

app.get '/', (req, res) ->
  res.render('index', { layout: false })

app.get '/bookmarklet.js', (req, res) ->
  res.header('Content-Type', 'text/javascript')
  res.render('bookmarklet.ejs', {
    layout: false,
    locals: {
      to: req.param('to')
    }
  })

app.get '/go', (req, res) ->
  # Provide some backwards compat...
  res.contentType('text/javascript')
  if verifyParams(req)
    Helpers.processRegular(req, res)
  else
    res.send("alert('Invalid request. Missing query params.');")

app.listen(9090)

socket = IO.listen(app)
socket.on 'connection', (client) ->
  client.on 'message', (data) ->
    json = JSON.parse(data)
    Helpers.processSocketIO(json.url, json.to, client)