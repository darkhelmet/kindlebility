Fs = require('fs')
Url = require('url')
Sys = require('sys')
Query = require('querystring')
Readability = require('./readability/lib/readability')
Spawn = require('child_process').spawn
Request = require('request')
Promise = require('./promised-io/lib/promise')
Config = JSON.parse(Fs.readFileSync('config.json', 'utf8'))
Postmark = 'http://api.postmarkapp.com/email'
UserAgent = "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_5; en-US) AppleWebKit/534.10 (KHTML, like Gecko) Chrome/8.0.552.215 Safari/534.10"

error = (client, msg) ->
  Sys.puts("ERROR: #{msg}")
  client.send(msg)
  client.send('done')

RetrievePage = (args) ->
  client = args.client
  client.send('1/6 Retrieving page...')
  defer = new Promise.defer()
  options = {
    uri: args.url,
    headers: {
      'User-Agent': UserAgent
    }
  }
  Request.get options, (error, response, body) ->
    if error?
      msg = 'Failed to retrieve page.'
      error(client, msg)
      defer.reject(msg)
    else
      client.send('1/6 Retrieving page...Done!')
      defer.resolve({
        client: client,
        response: response,
        body: body,
        url: args.url,
        to: args.to
      })
  options.request.socket.setTimeout(10000)
  defer

RunReadability = (args) ->
  client = args.client
  client.send('2/6 Running Readability...')
  defer = new Promise.defer()
  Readability.parse args.body, args.url, (result) ->
    if result.error
      msg = 'Failed running Readability'
      error(client, msg)
      defer.reject(msg)
    else
      client.send('2/6 Running Readability...Done!')
      defer.resolve({
        client: client,
        url: args.url,
        result: result,
        to: args.to
      })
  defer

WriteFile = (args) ->
  client = args.client
  client.send('3/6 Writing HTML...')
  defer = new Promise.defer()
  filename = Hash.sha1(args.url)
  Fs.writeFile "#{filename}.html", args.result.content, (err) ->
    if err?
      msg = 'Error saving Readability HTML'
      error(client, msg)
      defer.reject(msg)
    else
      client.send('3/6 Writing HTML...Done!')
      defer.resolve({
        client: client,
        filename: filename,
        url: args.url,
        title: args.result.title,
        to: args.to
      })
  defer

WebkitHtmlToPdf = (args) ->
  client = args.client
  client.send('4/6 Running wkhtmltopdf...')
  defer = new Promise.defer()
  filename = args.filename
  wkhtmltopdf = Spawn('wkhtmltopdf', ['--page-size', 'letter', '--encoding', 'utf-8', "#{filename}.html", "#{filename}.pdf"])
  wkhtmltopdf.on 'exit', (code) ->
    if 0 != code
      msg = "Error running wkhtmltopdf. (#{code})"
      error(client, msg)
      defer.reject(msg)
    else
      client.send('4/6 Running wkhtmltopdf...Done!')
      defer.resolve({
        client: client,
        filename: filename,
        url: args.url,
        title: args.title,
        to: args.to
      })
  defer

ReadFile = (args) ->
  client = args.client
  client.send('5/6 Reading PDF...')
  defer = new Promise.defer()
  Fs.readFile "#{args.filename}.pdf", 'base64', (err, data) ->
    if err?
      msg = "Error reading PDF."
      error(client, msg)
      defer.reject(msg)
    else
      client.send('5/6 Reading PDF...Done!')
      defer.resolve({
        client: client,
        to: args.to,
        url: args.url,
        title: args.title,
        data: data,
        filename: args.filename
      })
  defer

SendEmail = (args) ->
  client = args.client
  client.send('6/6 Sending email...')
  defer = new Promise.defer()
  requestBody = JSON.stringify({
    From: Config.email.from,
    To: args.to,
    Subject: 'convert',
    TextBody: "Straight to your Kindle: #{args.url}",
    Attachments: [{
      # Force tto ASCII otherwise Postmark doesn't like it
      Name: unescape(encodeURIComponent("#{args.title}.pdf")),
      Content: args.data,
      ContentType: 'application/pdf'
    }]
  })
  Request {
    uri: Postmark,
    method: 'POST',
    body: requestBody,
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      'X-Postmark-Server-Token': Config.postmark
    }
  }, (error, response, body) ->
    switch response.statusCode
      when 401
        msg = "Server configuration error."
        error(client, msg)
        defer.reject(msg)
      when 422
        msg = "Error sending email (malformed request)."
        error(client, msg)
        defer.reject(msg)
        Sys.puts("Malformed request: #{body}")
      when 200
        client.send('6/6 Sending email...Done!')
        client.send('done')
        Sys.puts("Everything went smoothly.")
      else
        msg = "Error sending email (other)."
        error(client, msg)
        defer.reject(msg)
        Sys.puts("Some other stupid problem: #{body}")
    Fs.unlink("#{args.filename}.pdf")
    Fs.unlink("#{args.filename}.html")

exports.verifyParams = (req) ->
  url = Url.parse(req.url)
  return false unless url.query?
  query = Query.parse(url.query)
  query.to? ? true : false

exports.processSocketIO = (url, to, client) ->
  Promise.seq([
    RetrievePage,
    RunReadability,
    WriteFile,
    WebkitHtmlToPdf,
    ReadFile,
    SendEmail
  ], {
    url: url,
    to: to,
    client: client
  })