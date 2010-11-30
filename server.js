var Chain, Config, Fs, Http, Postmark, Query, Readability, Request, Spawn, Sys, Url, fourOhFour, job;
require('joose');
require('joosex-namespace-depended');
require('hash');
Url = require('url');
Fs = require('fs');
Http = require('http');
Query = require('querystring');
Sys = require('sys');
Readability = require('./readability/lib/readability');
Spawn = require('child_process').spawn;
Request = require('request');
Config = JSON.parse(Fs.readFileSync('config.json', 'utf8'));
Postmark = require('./postmark')(Config.postmark, {
  ssl: true
});
Chain = require('./chain-gang').create({
  workers: 1
});
fourOhFour = function(res) {
  res.writeHead(404, {
    'Content-Length': 0
  });
  return res.end();
};
job = function(url) {
  return function(worker) {
    return Request({
      uri: url
    }, function(error, response, body) {
      if (typeof error !== "undefined" && error !== null) {
        return worker.finish();
      } else {
        try {
          return Readability.parse(body, url, function(result) {
            var filename;
            filename = Hash.sha1(url);
            return Fs.writeFile("" + (filename) + ".html", result.content, function(err) {
              var wkhtmltopdf;
              if (typeof err !== "undefined" && err !== null) {
                Sys.puts('failed writing HTML file');
                return worker.finish();
              } else {
                wkhtmltopdf = Spawn('wkhtmltopdf', ['--page-size', 'letter', '--encoding', 'utf-8', ("" + (filename) + ".html"), ("" + (filename) + ".pdf")]);
                return wkhtmltopdf.on('exit', function(code) {
                  if (0 === code) {
                    return Fs.readFile("" + (filename) + ".pdf", 'base64', function(err, data) {
                      if (typeof err !== "undefined" && err !== null) {
                        Sys.puts("error reading file");
                        return worker.finish();
                      } else {
                        Sys.puts('sending to postmark');
                        return Postmark.send({
                          From: Config.email.from,
                          To: Config.email.to,
                          Subject: 'convert',
                          TextBody: 'Straight to your Kindle!',
                          Attachments: [
                            {
                              Name: ("" + (result.title) + ".pdf"),
                              Content: data,
                              ContentType: 'application/pdf'
                            }
                          ]
                        }, function(error, response, body) {
                          switch (response.statusCode) {
                            case 401:
                              Sys.puts('Incorrect API key');
                              break;
                            case 422:
                              Sys.puts('Malformed request');
                              break;
                            case 200:
                              Sys.puts('Everything went smoothly');
                              break;
                            default:
                              Sys.puts('Some other stupid problem');
                          }
                          Fs.unlink("" + (filename) + ".pdf");
                          Fs.unlink("" + (filename) + ".html");
                          return worker.finish();
                        });
                      }
                    });
                  } else {
                    Sys.puts("wkhtmltopdf exited with code " + (code));
                    return worker.finish();
                  }
                });
              }
            });
          });
        } catch (e) {
          Sys.puts("caught an error: " + (e));
          return worker.finish();
        }
      }
    });
  };
};
Http.createServer(function(req, res) {
  var _ref, query, url;
  url = Url.parse(req.url);
  if (typeof (_ref = url.query) !== "undefined" && _ref !== null) {
    query = Query.parse(url.query);
    if ((typeof (_ref = query.u) !== "undefined" && _ref !== null) && query.key === Config.key) {
      url = query.u;
      res.writeHead(200, {
        'Content-Length': 0
      });
      res.end();
      return Chain.add(job(url));
    } else {
      return fourOhFour(res);
    }
  } else {
    return fourOhFour(res);
  }
}).listen(parseInt(process.ARGV[2] || '8080'));