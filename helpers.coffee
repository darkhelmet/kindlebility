Fs = require('fs')
Config = JSON.parse(Fs.readFileSync('config.json', 'utf8'))

error = (client, msg) ->
  client.send(msg)
  client.send('done')

retrievePage = (url, back) ->
  Request { uri: url, headers: { 'User-Agent': UserAgent } }, (error, response, body) ->
    back(error, body)

exports.processSocketIO = (url, to, client) ->
  retrievePage url, (error, body) ->



  client.send('Still working...')
  setTimeout((->
    client.send('done')
  ), 2500)

exports.processRegular = (req, res) ->
  to = req.param('to')
  url = req.param('u')
  error = (msg) ->
    res.send("alert(\"#{msg}\");")

  Request { uri: url, headers: { 'User-Agent': UserAgent } }, (error, response, body) ->
    if error?
      error("There was an error retrieving the page...")
    else
      try
        Readability.parse body, url, (result) ->
          filename = Hash.sha1(url)
          Fs.writeFile "#{filename}.html", result.content, (err) ->
            if err?
              error("Filesystem error writing HTML file.")
            else
              wkhtmltopdf = Spawn('wkhtmltopdf', ['--page-size', 'letter', '--encoding', 'utf-8', "#{filename}.html", "#{filename}.pdf"])
              wkhtmltopdf.on 'exit', (code) ->
                if 0 == code
                  Fs.readFile "#{filename}.pdf", 'base64', (err, data) ->
                    if err?
                      error("Filesystem error reading PDF.")
                    else
                      Sys.puts('Sending to postmark')
                      requestBody = JSON.stringify({
                        From: Config.email.from,
                        To: to,
                        Subject: 'convert',
                        TextBody: "Straight to your Kindle: #{url}",
                        Attachments: [{
                          # Force tto ASCII otherwise Postmark doesn't like it
                          Name: unescape(encodeURIComponent("#{result.title}.pdf")),
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
                        switch response.statusCode
                          when 401
                            error("Server configuration error.")
                          when 422
                            error("Error sending email (malformed request).")
                            Sys.puts("Malformed request: #{body}")
                          when 200
                            Sys.puts("Everything went smoothly.")
                          else
                            error("Error sending email (other).")
                            Sys.puts("Some other stupid problem: #{body}")
                        Fs.unlink("#{filename}.pdf")
                        Fs.unlink("#{filename}.html")
                else
                  error("Error with wkhtmltopdf: #{code}")
      catch e
        error("An error occurred.")
