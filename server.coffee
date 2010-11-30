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
Postmark = require('./postmark')(Config.postmark, { ssl: true })
Chain = require('./chain-gang').create({ workers: 1 })

fourOhFour = (res) ->
  res.writeHead(404, {
    'Content-Length': 0
  })
  res.end()

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
                        Postmark.send {
                          From: Config.email.from,
                          To: Config.email.to,
                          Subject: 'convert',
                          TextBody: 'Straight to your Kindle!',
                          Attachments: [{
                            Name: "#{result.title}.pdf",
                            Content: data,
                            ContentType: 'application/pdf'
                          }]
                        }, (error, response, body) ->
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
        'Content-Length': 0
      })
      res.end()
      Chain.add job(url)
    else
      fourOhFour(res)
  else
    fourOhFour(res)
).listen(parseInt(process.ARGV[2] || '8080'));