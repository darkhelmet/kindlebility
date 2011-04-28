((url) ->
  log = (message) ->
    if console? && console.log?
      console.log("** kindlebility **\t#{message}")

  body = document.getElementsByTagName('body')[0]
  getDiv = () ->
    document.getElementById('kindlebility')

  # Original readability bookmarklet
  tryGetOriginalReadability = () ->
    e = document.getElementById('readInner')
    if e?
      {
        content: e.outerHTML,
        title: e.children[0].innerText
      }
    else
      null

  # New readability
  tryGetNewReadability = () ->
    e = document.getElementById('rdb-article')
    if e?
      {
        content: e.outerHTML,
        title: document.getElementById('article-entry-title').innerText
      }
    else
      null

  tryGetReadabilityResult = () ->
    tryGetOriginalReadability() || tryGetNewReadability()

  div = getDiv()
  host = div.getAttribute('data-host')
  kindlebility = () ->
    log('starting process')
    to = div.getAttribute('data-email')
    socket = new io.Socket(host.split(':')[0], { port: 9090 })
    socket.on 'message', (data) ->
      if 'done' == data
        log('done')
        setTimeout((-> body.removeChild(div)), 2500)
        socket.disconnect()
      else
        log(data)
        div.innerHTML = data
        te = document.createTextNode(' ')
        div.appendChild(te)
        setTimeout((-> div.removeChild(te)), 50)

    socket.connect()
    log('socket connected')
    message = { url: url, to: to }
    readabilityResult = tryGetReadabilityResult()
    message['result'] = readabilityResult if e?
    json = JSON.stringify(message)
    log("sending initial message: #{json}")
    socket.send(json)

  loadSocketIO = (callback) ->
    log('loading socket.io')
    script = document.createElement('script')
    script.async = 'async'
    script.type = 'text/javascript'
    script.src = 'http://' + host + '/socket.io/socket.io.js'
    script.onload = script.onreadystatechange = callback
    head = document.getElementsByTagName('head')[0]
    head.appendChild(script);

  socketIOLoaded = () ->
    window.io?.Socket && 'function' == typeof(window.io.Socket)

  if socketIOLoaded()
    log('socket.io already loaded')
    kindlebility()
  else
    log('socket.io not loaded')
    loadSocketIO(kindlebility)

)(document.location.href)
