$(document).ready(function() {
  $('#email').change(function() {
    $('#extra').slideToggle();
    $('html, body').animate({
      scrollTop: $(document).height()
    });
    $('#bookmarklet').html('Send to my Kindle!').attr('href', "javascript:(function() { \
      var script = document.createElement('script'); \
      script.type = 'text/javascript'; \
      script.src = 'http://kindlebility.darkhax.com/bookmarklet.js?to=" + encodeURIComponent(this.value) + "&t=' + (new Date()).getTime(); \
      document.getElementsByTagName('head')[0].appendChild(script); \
    })();");
  });

  $.get('/donate.html', function(data) {
    $('.center').append(data);
  });
});