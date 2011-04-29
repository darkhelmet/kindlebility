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
    connected = false
    to = div.getAttribute('data-email')
    socket = new io.Socket(host.split(':')[0], { port: 9090 })
    socket.connect()
    socket.on 'connect', ->
      # Ensure this only ever happens once
      unless connected
        connected = true
        log('socket connected')
        message = { url: url, to: to }
        readabilityResult = tryGetReadabilityResult()
        message['result'] = readabilityResult if e?
        json = JSON.stringify(message)
        log("sending initial message: #{json}")
        socket.send(json)

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

  # Let's only run this stuff once
  if window.kindlebility isnt true
    window.kindlebility = true
    if url.match(/kindlebility\.(darkhax\.)?com/) == null
      if socketIOLoaded()
        log('socket.io already loaded')
        kindlebility()
      else
        log('socket.io not loaded')
        loadSocketIO(kindlebility)
    else
      alert('You have to use this on a page you want to read, not the Kindlebility page!')
  else
    alert('Kindlebility has already ran! Refresh the page to try again.')

)(document.location.href)
