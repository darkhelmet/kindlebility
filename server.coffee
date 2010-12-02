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

args = ArgsParser.parse()

fourOhFour = (reply) ->
  reply(404, {
    'Content-Type': 'text/javascript'
  }, "alert('You fail...');")

job = (url) ->
  (worker) ->
    Request { uri: url }, (error, response, body) ->
      if error?
        worker.finish()
      else
        try
          Readability.parse body, url, (result) ->
            filename = Hash.sha1(url)
            Fs.writeFile "#{filename}.html", result.content, (err) ->
              if err?
                Sys.puts('failed writing HTML file')
                worker.finish()
              else
                wkhtmltopdf = Spawn('wkhtmltopdf', ['--page-size', 'letter', '--encoding', 'utf-8', "#{filename}.html", "#{filename}.pdf"])
                wkhtmltopdf.on 'exit', (code) ->
                  if 0 == code
                    Fs.readFile "#{filename}.pdf", 'base64', (err, data) ->
                      if err?
                        Sys.puts("error reading file")
                        worker.finish()
                      else
                        Sys.puts('sending to postmark')
                        Request {
                          uri: Postmark,
                          method: 'POST',
                          body: JSON.stringify({
                            From: Config.email.from,
                            To: Config.email.to,
                            Subject: 'convert',
                            TextBody: 'Straight to your Kindle!',
                            Attachments: [{
                              Name: "#{result.title}.pdf",
                              Content: data,
                              ContentType: 'application/pdf'
                            }]
                          }),
                          headers: {
                            Accept: 'application/json',
                            'Content-Type': 'application/json',
                            'X-Postmark-Server-Token': Config.postmark
                          }
                        }, (error, response, body) ->
                          Sys.puts('there was an error...') if error?
                          switch response.statusCode
                            when 401
                              Sys.puts('Incorrect API key')
                            when 422
                              Sys.puts('Malformed request')
                            when 200
                              Sys.puts('Everything went smoothly')
                            else
                              Sys.puts('Some other stupid problem')
                          Fs.unlink("#{filename}.pdf")
                          Fs.unlink("#{filename}.html")
                          worker.finish()
                  else
                    Sys.puts("wkhtmltopdf exited with code #{code}")
                    worker.finish()
        catch e
          Sys.puts("caught an error: #{e}")
          worker.finish()


recv = args['--recv'] || 'tcp://127.0.0.1:9997'
send = args['--send'] || 'tcp://127.0.0.1:9996'
identity = args['--identity'] || 'kindlebility'

Mongrel2.connect recv, send, identity, (msg, reply) ->
  url = Url.parse(msg.headers.URI)
  if url.query?
    query = Query.parse(url.query)
    if query.u?
      if query.key == Config.key
        url = query.u
        Chain.add job(url)
        reply(200, {
          'Content-Type': 'text/javascript'
        }, "alert('All good boss!');")
      else
        reply(403, {
          'Content-Type': 'text/javascript'
        }, "alert('Not authorized');")
    else
      reply(400, {
        'Content-Type': 'text/javascript'
      }, "alert('No URL present');")
  else
    reply(412, {
      'Content-Type': 'text/javascript'
    }, "alert('Missing parameters');")