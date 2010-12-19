var ArgsParser, Chain, Config, Fs, Http, Mongrel2, Postmark, PublicDirectory, Query, Readability, Request, Spawn, Sys, Url, UserAgent, args, identity, job, publicDir, recv, send;
require('joose');
require('joosex-namespace-depended');
require('hash');
ArgsParser = require('argsparser');
Url = require('url');
Fs = require('fs');
Http = require('http');
Query = require('querystring');
Sys = require('sys');
Readability = require('./readability/lib/readability');
Spawn = require('child_process').spawn;
Request = require('request');
Config = JSON.parse(Fs.readFileSync('config.json', 'utf8'));
Mongrel2 = require('mongrel2');
Postmark = 'http://api.postmarkapp.com/email';
Chain = require('./chain-gang').create();
UserAgent = "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_5; en-US) AppleWebKit/534.10 (KHTML, like Gecko) Chrome/8.0.552.215 Safari/534.10";
args = ArgsParser.parse();
job = function(url, to) {
  return function(worker) {
    return Request({
      uri: url,
      headers: {
        'User-Agent': UserAgent
      }
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
                Sys.puts('Failed writing HTML file');
                return worker.finish();
              } else {
                wkhtmltopdf = Spawn('wkhtmltopdf', ['--page-size', 'letter', '--encoding', 'utf-8', ("" + (filename) + ".html"), ("" + (filename) + ".pdf")]);
                return wkhtmltopdf.on('exit', function(code) {
                  if (0 === code) {
                    return Fs.readFile("" + (filename) + ".pdf", 'base64', function(err, data) {
                      var requestBody;
                      if (typeof err !== "undefined" && err !== null) {
                        Sys.puts('Error reading file');
                        return worker.finish();
                      } else {
                        Sys.puts('Sending to postmark');
                        requestBody = JSON.stringify({
                          From: Config.email.from,
                          To: to,
                          Subject: 'convert',
                          TextBody: ("Straight to your Kindle: " + (url)),
                          Attachments: [
                            {
                              Name: unescape(encodeURIComponent("" + (result.title) + ".pdf")),
                              Content: data,
                              ContentType: 'application/pdf'
                            }
                          ]
                        });
                        return Request({
                          uri: Postmark,
                          method: 'POST',
                          body: requestBody,
                          headers: {
                            Accept: 'application/json',
                            'Content-Type': 'application/json',
                            'X-Postmark-Server-Token': Config.postmark
                          }
                        }, function(error, response, body) {
                          if (typeof error !== "undefined" && error !== null) {
                            Sys.puts('There was an error...');
                          }
                          switch (response.statusCode) {
                            case 401:
                              Sys.puts('Incorrect API key');
                              break;
                            case 422:
                              Sys.puts("Malformed request: " + (body));
                              break;
                            case 200:
                              Sys.puts('Everything went smoothly');
                              break;
                            default:
                              Sys.puts("Some other stupid problem: " + (body));
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
          Sys.puts("Caught an error: " + (e));
          return worker.finish();
        }
      }
    });
  };
};
recv = args['--recv'] || 'tcp://127.0.0.1:9997';
send = args['--send'] || 'tcp://127.0.0.1:9996';
identity = args['--identity'] || 'kindlebility';
PublicDirectory = function(_arg) {
  this.mapping = _arg;
  return this;
};
PublicDirectory.prototype.serve = function(msg, reply) {
  var file;
  if (file = this.mapping[msg.path]) {
    reply(200, {
      'Content-Type': file.contentType
    }, file.content);
    return true;
  } else {
    return false;
  }
};
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
});
Mongrel2.connect(recv, send, identity, function(msg, reply) {
  var _ref, query, url;
  if (!(publicDir.serve(msg, reply))) {
    url = Url.parse(msg.headers.URI);
    if (typeof (_ref = url.query) !== "undefined" && _ref !== null) {
      query = Query.parse(url.query);
      if ((typeof (_ref = query.u) !== "undefined" && _ref !== null) && (typeof (_ref = query.to) !== "undefined" && _ref !== null)) {
        Chain.add(job(query.u, query.to));
        return reply(200, {
          'Content-Type': 'text/javascript'
        }, "alert('All good boss!');");
      } else {
        return reply(400, {
          'Content-Type': 'text/javascript'
        }, "alert('No URL or to address present!');");
      }
    } else {
      return reply(412, {
        'Content-Type': 'text/javascript'
      }, "alert(\"You're missing query params!\");");
    }
  }
});