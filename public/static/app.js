$(document).ready(function() {
  $('#email').change(function() {
    if ('' == this.value) {
      $('#extra').slideUp();
    } else {
      $('#extra').slideDown();
    }
    $('html, body').animate({
      scrollTop: $(document).height()
    });
    var script = "javascript:(function() { \
      var setupDiv = function() { \
        var id = 'kindlebility'; \
        var div = document.getElementById(id); \
        var body = document.getElementsByTagName('body')[0]; \
        if (null != div) { \
          body.removeChild(div); \
        } \
        div = document.createElement('div'); \
        div.id = id; div.style.width = '200px'; div.style.height = '30px'; \
        div.setAttribute('data-email', '" + encodeURIComponent(this.value) + "'); \
        div.setAttribute('data-host', '" + HOST + "'); \
        div.style.position = 'fixed'; div.style.top = '10px'; div.style.left = '10px'; \
        div.style.background = 'white'; div.style.color = 'black'; div.style.borderColor = 'black'; div.style.borderStyle = 'solid'; \
        div.style.borderWidth = '2px'; div.style.zIndex = '99999999'; div.style.padding = '5px'; \
        div.style.paddingTop = '16px'; div.style.textAlign = 'center'; \
        div.innerHTML = 'Working...'; \
        body.appendChild(div); \
      }; \
      setupDiv(); \
      var script = document.createElement('script'); \
      script.type = 'text/javascript'; \
      script.src = 'http://" + HOST + "/static/bookmarklet.js?t=' + (new Date()).getTime(); \
      document.getElementsByTagName('head')[0].appendChild(script); \
    })();";
    $('#bookmarklet').html('Send to my Kindle!').attr('href', script);
    $('#ios').html(script);
  });

  $('#iosLink').click(function(event) {
    $('#ios').slideToggle();
    return false;
  });

  $.get('/static/donate.html', function(data) {
    $('.center').append(data);
  });
});