Fs = require('fs')
Url = require('url')
Sys = require('sys')
Query = require('querystring')
Readability = require('./readability/lib/readability')
Spawn = require('child_process').spawn
Request = require('./request/main')
Promise = require('./promised-io/lib/promise')
Config = JSON.parse(Fs.readFileSync('config.json', 'utf8'))
Postmark = 'http://api.postmarkapp.com/email'
UserAgent = "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_5; en-US) AppleWebKit/534.10 (KHTML, like Gecko) Chrome/8.0.552.215 Safari/534.10"

Hoptoad = require('hoptoad-notifier').Hoptoad
Hoptoad.key = Config.hoptoad

error = (client, msg) ->
  Sys.puts("ERROR: #{msg}")
  client.send(msg)
  client.send('done')

formatProgress = (step, msg) ->
  "#{step}/6 #{msg}..."

formatProgressDone = (step, msg) ->
  "#{formatProgress(step, msg)}Done!"

templatize = (step, msg, func) ->
  (args) ->
    client = args.client
    client.send(formatProgress(step, msg))
    defer = new Promise.defer()
    success = (obj) ->
      obj['client'] = client
      client.send(formatProgressDone(step, msg))
      defer.resolve(obj)
    fail = (msg) ->
      error(client, msg)
      defer.reject(msg)
    try
      func(args, success, fail)
    catch e
      Hoptoad.notify(e)
      msg = 'An error occurred.'
      error(client, msg)
      defer.reject(msg)
    defer

RetrievePage = templatize 1, 'Retrieving page', (args, success, fail) ->
  options = {
    uri: args.url,
    headers: {
      'User-Agent': UserAgent
    }
  }
  Request options, (err, response, body) ->
    if err?
      fail("Failed to retrieve page: #{args.url}")
    else
      success({
        response: response,
        body: body,
        url: args.url,
        to: args.to
      })

RunReadability = templatize 2, 'Running Readability', (args, success, fail) ->
  Readability.parse args.body, args.url, (result) ->
    if result.error
      fail("Failed running Readability: #{args.url}")
    else
      success({
        url: args.url,
        result: result,
        to: args.to
      })

WriteFile = templatize 3, 'Writing HTML', (args, success, fail) ->
  filename = Hash.sha1("#{args.url}:#{args.to}:#{(new Date).getTime()}")
  Fs.writeFile "#{filename}.html", args.result.content, (err) ->
    if err?
      fail('Error saving Readability HTML')
    else
      success({
        filename: filename,
        url: args.url,
        title: args.result.title,
        to: args.to
      })

WebkitHtmlToPdf = templatize 4, 'Running wkhtmltopdf', (args, success, fail) ->
  filename = args.filename
  wkhtmltopdf = Spawn('wkhtmltopdf', ['--page-size', 'letter', '--encoding', 'utf-8', "#{filename}.html", "#{filename}.pdf"])
  wkhtmltopdf.on 'exit', (code) ->
    if 0 != code
      fail("Error running wkhtmltopdf. (#{code})")
    else
      success({
        filename: filename,
        url: args.url,
        title: args.title,
        to: args.to
      })

ReadFile = templatize 5, 'Reading PDF', (args, success, fail) ->
  Fs.readFile "#{args.filename}.pdf", 'base64', (err, data) ->
    if err?
      fail("Error reading PDF.")
    else
      success({
        to: args.to,
        url: args.url,
        title: args.title,
        data: data,
        filename: args.filename
      })

SendEmail = templatize 6, 'Sending email', (args, success, fail) ->
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
  }, (err, response, body) ->
    switch response.statusCode
      when 401
        fail('Server configuration error.')
      when 422
        fail('Error sending email (malformed request).')
      when 200
        success({})
        args.client.send('done')
        Sys.puts("Everything went smoothly.")
      else
        fail('Error sending email (other).')
    Fs.unlink("#{args.filename}.pdf")
    Fs.unlink("#{args.filename}.html")

exports.verifyParams = (req) ->
  url = Url.parse(req.url)
  return false unless url.query?
  query = Query.parse(url.query)
  query.to? ? true : false

exports.processSocketIO = (args) ->
  sequence = if args.result?
    [
      WriteFile,
      WebkitHtmlToPdf,
      ReadFile,
      SendEmail
    ]
  else
    [
      RetrievePage,
      RunReadability,
      WriteFile,
      WebkitHtmlToPdf,
      ReadFile,
      SendEmail
    ]
  Promise.seq(sequence, args)