Quill   = require('../quill')
Tooltip = require('./tooltip')
_       = Quill.require('lodash')
dom     = Quill.require('dom')
Range   = require('../lib/range')


class LinkTooltip extends Tooltip
  @DEFAULTS:
    maxLength: 50
    styles:
      '.link-tooltip-container':
        'padding': '5px 10px'
      '.link-tooltip-container input.input':
        'width': '170px'
      '.link-tooltip-container.editing input.input, .link-tooltip-container.editing a.save, .link-tooltip-container.editing a.unlink, .link-tooltip-container.editing div#unlink ':
        'display': 'inline-block'
      '.show':
        'display': 'inline-block'
      '.hide':
        'display': 'none'
    template:
     '<span class="title">Web URL:&nbsp;</span>
      <input class="url-input" id="link-tooltip-url" type="text">
      <span class="title">&nbsp;Display Text:&nbsp;</span>
      <input class="text-input" id="link-tooltip-text" type="text">
      <span>&nbsp;&#45;&nbsp;</span>
      <a href="javascript:;" class="save">Save</a>
      <div id="unlink">
        <span>&nbsp;&#45;&nbsp;</span>
        <a href="javascript:;" class="unlink">Unlink</a>
      </div>'

  constructor: (@quill, @options) ->
    @options.styles = _.defaults(@options.styles, Tooltip.DEFAULTS.styles)
    @options = _.defaults(@options, Tooltip.DEFAULTS)
    super(@quill, @options)
    dom(@container).addClass('link-tooltip-container')
    @url_textbox = @container.querySelector('.url-input')
    @text_textbox = @container.querySelector('.text-input')
    this.initListeners()

  initListeners: ->
    @quill.on(@quill.constructor.events.SELECTION_CHANGE, (range) =>
      return unless range?
      @range = range # set range here as it seems to disappear in _onToolbar
      anchor = this._findAnchor(range)
      if anchor
        # Don't show tooltip if anchor (link) is at end of content and the range is at the end of link.
        # This is needed to prevent the link tooltip from constatly showing up once a link has been inserted
        #   at the end of content.
        if @quill.getLength() - 1 == range.start # subtract 1 from length because range.start is 0-based index
          return

        this.setMode(anchor.href, anchor.text)
        this.show(anchor)
      else
        this.hide()
    )
    dom(@container.querySelector('.save')).on('click', _.bind(this.saveLink, this))
    dom(@container.querySelector('.unlink')).on('click', _.bind(this._unlink, this))

    this.initTextbox(@url_textbox, this.saveLink, this.hide)
    @quill.onModuleLoad('toolbar', (toolbar) =>
      toolbar.initFormat('link', _.bind(this._onToolbar, this))
    )

  saveLink: ->
    url = this._normalizeURL(@url_textbox.value)
    text = @text_textbox.value

    # set @range here as it seems to disappear
    @range = @quill.editor.selection.range

    if @range?
      anchor = this._findAnchor(@range)
      if anchor
        anchor.href = url
        anchor.text = text
      else
        @quill.deleteText(@range, 'user')
        @quill.insertText(@range, text, url, 'user')
        @quill.formatText(@range.start, @range.start + text.length, 'link', url, 'user')
    this.hide()
    this.setMode(url, text)

  setMode: (url, text) ->
    @url_textbox.value = url
    @url_textbox.focus()
    if url
      dom(@container.querySelector('div#unlink')).toggleClass('hide', false)
      dom(@container.querySelector('div#unlink')).toggleClass('show', true)
    else
      dom(@container.querySelector('div#unlink')).toggleClass('hide', true)
      dom(@container.querySelector('div#unlink')).toggleClass('show', false)

    _.defer( =>
      url_length = url?length ? 0
      url_textbox_range = new Range(url_length, url_length)
      @url_textbox.setSelectionRange(url_textbox_range.start, url_textbox_range.end) # set range to be length of url
    )

    @text_textbox.value = text

  _findAnchor: (range) ->
    [start_leaf, offset] = @quill.editor.doc.findLeafAt(range.start, true)
    start_node = start_leaf.node if start_leaf
    [end_leaf, offset] = @quill.editor.doc.findLeafAt(range.end, true)
    end_node = end_leaf.node if end_leaf

    while start_node
      if start_node.tagName == 'A'
        break
      start_node = start_node.parentNode
    while end_node
      if end_node.tagName == 'A'
        break
      end_node = end_node.parentNode

    if start_node == end_node
      return start_node
    else
      return null

  _unlink: ->
    this._onToolbar(@range, false)

  _onToolbar: (range, value) ->
    console.log('onToolbar')
    saved_range = @quill.editor.selection.range
    return unless saved_range
    @range = saved_range
    if value
      this.setMode(null, @quill.getText(saved_range))
      nativeRange = @quill.editor.selection._getNativeRange()
      this.show(nativeRange)
    else
      console.log('deleting text. hiding popup. range:', saved_range)
      #@quill.formatText(saved_range, 'link', false, 'user')
      anchor = this._findAnchor(saved_range)
      if anchor
        # replcae anchor with anchor's text
        dom(anchor).replace(document.createTextNode(anchor.text))
        @quill.setSelection(saved_range)
        @range = saved_range
        this.hide()

  _normalizeURL: (url) ->
    url = 'http://' + url unless /^https?:\/\//.test(url)
    return url

  _suggestURL: (range) ->
    text = @quill.getText(range)
    return this._normalizeURL(text)


Quill.registerModule('link-tooltip', LinkTooltip)
module.exports = LinkTooltip
