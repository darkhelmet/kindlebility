require('joose')
require('joosex-namespace-depended')
require('hash')
Url = require('url')
Fs = require('fs')
Http = require('http')
Query = require('querystring')
Sys = require('sys')
Readability = require('./readability/lib/readability')
Spawn = require('child_process').spawn
Request = require('request')
Config = JSON.parse(Fs.readFileSync('config.json', 'utf8'))
Postmark = 'http://api.postmarkapp.com/email'
Chain = require('./chain-gang').create()

fourOhFour = (res) ->
  res.writeHead(404, {
    'Content-Type': 'text/javascript'
  })
  res.end("alert('You fail...');")

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

Http.createServer((req, res) ->
  url = Url.parse(req.url)
  if url.query?
    query = Query.parse(url.query)
    if query.u? && query.key == Config.key
      url = query.u
      res.writeHead(200, {
        'Content-Type': 'text/javascript'
      })
      res.end("alert('All good boss!');")
      Chain.add job(url)
    else
      fourOhFour(res)
  else
    fourOhFour(res)
).listen(parseInt(process.ARGV[2] || '8080'));