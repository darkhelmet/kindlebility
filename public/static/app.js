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
    $('#bookmarklet').html('Send to my Kindle!').attr('href', "javascript:(function() { \
      var setupDiv = function() { \
        var id = 'kindlebility'; \
        var div = document.getElementById(id); \
        if (null == div) { \
          div = document.createElement('div'); \
          div.id = id; div.style.width = '200px'; div.style.height = '30px'; \
          div.style.position = 'fixed'; div.style.top = '10px'; div.style.left = '10px'; \
          div.style.background = 'white'; div.style.borderColor = 'black'; div.style.borderStyle = 'solid'; \
          div.style.borderWidth = '2px'; div.style.zIndex = '99999999'; div.style.padding = '5px'; \
          div.style.paddingTop = '16px'; div.style.textAlign = 'center'; \
          div.innerText = 'Working...'; \
          document.getElementsByTagName('body')[0].appendChild(div); \
        } \
      }; \
      setupDiv(); \
      var script = document.createElement('script'); \
      script.type = 'text/javascript'; \
      script.src = 'http://kindlebility.darkhax.com/bookmarklet.js?to=" + encodeURIComponent(this.value) + "&t=' + (new Date()).getTime(); \
      document.getElementsByTagName('head')[0].appendChild(script); \
    })();");
  });

  $.get('/static/donate.html', function(data) {
    $('.center').append(data);
  });
});