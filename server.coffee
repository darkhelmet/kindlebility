require('joose')
require('joosex-namespace-depended')
require('hash')
ArgsParser = require('argsparser')
Url = require('url')
Fs = require('fs')
Http = require('http')
Query = require('querystring')
Sys = require('sys')
Readability = require('./readability/lib/readability')
Spawn = require('child_process').spawn
Request = require('request')
Config = JSON.parse(Fs.readFileSync('config.json', 'utf8'))
Mongrel2 = require('mongrel2')
Postmark = 'http://api.postmarkapp.com/email'
Chain = require('./chain-gang').create()
UserAgent = "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_5; en-US) AppleWebKit/534.10 (KHTML, like Gecko) Chrome/8.0.552.215 Safari/534.10"

args = ArgsParser.parse()

job = (url, to) ->
  (worker) ->
    Request {
      uri: url,
      headers: {
        'User-Agent': UserAgent
      }
    }, (error, response, body) ->
      if error?
        worker.finish()
      else
        try
          Readability.parse body, url, (result) ->
            filename = Hash.sha1(url)
            Fs.writeFile "#{filename}.html", result.content, (err) ->
              if err?
                Sys.puts('Failed writing HTML file')
                worker.finish()
              else
                wkhtmltopdf = Spawn('wkhtmltopdf', ['--page-size', 'letter', '--encoding', 'utf-8', "#{filename}.html", "#{filename}.pdf"])
                wkhtmltopdf.on 'exit', (code) ->
                  if 0 == code
                    Fs.readFile "#{filename}.pdf", 'base64', (err, data) ->
                      if err?
                        Sys.puts('Error reading file')
                        worker.finish()
                      else
                        Sys.puts('Sending to postmark')
                        requestBody = JSON.stringify({
                          From: Config.email.from,
                          To: to,
                          Subject: 'convert',
                          TextBody: "Straight to your Kindle: #{url}",
                          Attachments: [{
                            # Force tto ASCII otherwise Postmark doesn't like it
                            Name: (new Buffer("#{result.title}.pdf", 'ascii')).toString(),
                            Content: data,
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
                          Sys.puts('There was an error...') if error?
                          switch response.statusCode
                            when 401
                              Sys.puts('Incorrect API key')
                            when 422
                              Sys.puts("Malformed request: #{body}")
                            when 200
                              Sys.puts('Everything went smoothly')
                            else
                              Sys.puts("Some other stupid problem: #{body}")
                          Fs.unlink("#{filename}.pdf")
                          Fs.unlink("#{filename}.html")
                          worker.finish()
                  else
                    Sys.puts("wkhtmltopdf exited with code #{code}")
                    worker.finish()
        catch e
          Sys.puts("Caught an error: #{e}")
          worker.finish()

recv = args['--recv'] || 'tcp://127.0.0.1:9997'
send = args['--send'] || 'tcp://127.0.0.1:9996'
identity = args['--identity'] || 'kindlebility'

class PublicDirectory
  constructor: (@mapping) ->

  serve: (msg, reply) ->
    if file = @mapping[msg.path]
      reply(200, {
        'Content-Type': file.contentType
      }, file.content)
      true
    else
      false

publicDir = new PublicDirectory({
  '/': {
    contentType: 'text/html',
    content: Fs.readFileSync('./public/index.html')
  },
  '/style.css': {
    contentType: 'text/css',
    content: Fs.readFileSync('./public/style.css')
  },
  '/zepto.js': {
    contentType: 'text/javascript',
    content: Fs.readFileSync('./public/zepto.js')
  }
})

Mongrel2.connect recv, send, identity, (msg, reply) ->
  unless publicDir.serve(msg, reply)
    url = Url.parse(msg.headers.URI)
    if url.query?
      query = Query.parse(url.query)
      if query.u? && query.to?
        Chain.add job(query.u, query.to)
        reply(200, {
          'Content-Type': 'text/javascript'
        }, "alert('All good boss!');")
      else
        reply(400, {
          'Content-Type': 'text/javascript'
        }, "alert('No URL or to address present!');")
    else
      reply(412, {
        'Content-Type': 'text/javascript'
      }, "alert(\"You're missing query params!\");")