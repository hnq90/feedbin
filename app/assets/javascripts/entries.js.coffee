window.feedbin ?= {}

jQuery ->
  new feedbin.EntriesPager()

class feedbin.EntriesPager
  constructor: ->
    @container = $('.entries')
    @container.on('scroll', @check)

  check: =>
    url = $('.pagination .next_page').attr('href')
    if @nearBottom() && url
      @container.unbind('scroll', @check)
      $.getScript url, =>
        @container.on('scroll', @check)

  nearBottom: =>
    height = @container.prop('scrollHeight') - @container.prop('offsetHeight')
    height - @container.scrollTop() < 1500
