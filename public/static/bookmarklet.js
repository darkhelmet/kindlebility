(function(url) {
  var body = document.getElementsByTagName('body')[0];
  var getDiv = function() {
    var id = 'kindlebility';
    return document.getElementById(id);
  };

  var div = getDiv();
  var host = div.getAttribute('data-host');
  var kindlebility = function() {
    var to = div.getAttribute('data-email');
    var socket = new io.Socket(host.split(':')[0], { port: 9090 });
    socket.on('message', function(data) {
      if ('done' == data) {
        setTimeout(function() {
          body.removeChild(div);
        }, 2500);
        socket.disconnect();
      } else {
        div.innerHTML = data;
      }
    });
    socket.connect();
    var message = { url: url, to: to };
    var readabilityElement = document.getElementById('readInner');
    if (null != readabilityElement) {
      message['result'] = {
        content: readabilityElement.outerHTML,
        title: readabilityElement.children[0].innerText
      };
    }
    socket.send(JSON.stringify(message));
  };

  var loadSocketIO = function(callback) {
    var script = document.createElement('script');
    script.type = 'text/javascript';
    script.src = 'http://' + host + '/socket.io/socket.io.js';
    script.onload = callback;
    var head = document.getElementsByTagName('head')[0];
    head.appendChild(script);
  };

  var socketIOLoaded = function() {
    return window.io && window.io.Socket && 'function' == typeof(window.io.Socket);
  };

  socketIOLoaded() ? kindlebility() : loadSocketIO(kindlebility);
})(document.location.href);