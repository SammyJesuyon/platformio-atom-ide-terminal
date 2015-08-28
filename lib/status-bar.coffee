{CompositeDisposable} = require 'atom'
{$, View} = require 'atom-space-pen-views'

TerminalPlusView = require './view'

window.jQuery = window.$ = $

module.exports =
class StatusBar extends View
  terminalViews: []
  activeIndex: 0

  @content: ->
    @div class: 'terminal-plus status-bar inline-block', =>
      @span class: "icon icon-plus inline-block-tight left", click: 'newTerminalView', outlet: 'plusBtn'
      @ul class: 'list-inline status-container left', outlet: 'statusContainer'
      @span class: "icon icon-x inline-block-tight right red", click: 'closeAll', outlet: 'closeBtn'

  initialize: (state={}) ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-workspace',
      'terminal-plus:new': => @newTerminalView()
      'terminal-plus:toggle': => @toggle()
      'terminal-plus:next': => @activeNextTerminalView()
      'terminal-plus:prev': => @activePrevTerminalView()
      'terminal-plus:hide': => @runInActiveView (i) -> i.hide()
      'terminal-plus:destroy': => @runInActiveView (i) -> i.destroy()

    @subscriptions.add atom.commands.add '.xterm',
      'terminal-plus:paste': => @runInOpenView (i) -> i.paste()
      'terminal-plus:copy': => @runInOpenView (i) -> i.copy()

    @registerContextMenu()

    @subscriptions.add atom.tooltips.add @plusBtn, title: 'New Terminal'
    @subscriptions.add atom.tooltips.add @closeBtn, title: 'Close All'

    @createTerminalView()
    @attach()

    @initializeSorting() if atom.config.get('terminal-plus.toggles.sortableStatus')

  registerContextMenu: ->
    @subscriptions.add atom.commands.add '.terminal-plus',
      'terminal-plus:status-red': (event) => @setStatusColor(event)
      'terminal-plus:status-orange': (event) => @setStatusColor(event)
      'terminal-plus:status-yellow': (event) => @setStatusColor(event)
      'terminal-plus:status-green': (event) => @setStatusColor(event)
      'terminal-plus:status-blue': (event) => @setStatusColor(event)
      'terminal-plus:status-purple': (event) => @setStatusColor(event)
      'terminal-plus:status-pink': (event) => @setStatusColor(event)
      'terminal-plus:status-cyan': (event) => @setStatusColor(event)
      'terminal-plus:status-magenta': (event) => @setStatusColor(event)
      'terminal-plus:status-default': (event) => @clearStatusColor(event)
      'terminal-plus:context-destroy': (event) ->
        $(event.target).closest('.term-status').data("terminalView").destroy()
      'terminal-plus:context-hide': (event) ->
        $(event.target).closest('.term-status').data("terminalView").close()

  initializeSorting: ->
    require '../resources/jquery-sortable'

    @statusContainer.sortable(
      cursor: "move"
      distance: 3
      hoverClass: "term-hover"
      helper: "clone"
      scroll: false
      tolerance: "intersect"
    )
    @statusContainer.disableSelection()
    @statusContainer.on 'sortstart', (event, ui) =>
      ui.item.oldIndex = ui.item.index()
      ui.item.activeTerminal = @terminalViews[@activeIndex]
    @statusContainer.on 'sortupdate', (event, ui) =>
      @moveTerminalView ui.item.oldIndex, ui.item.index(), ui.item.activeTerminal

  createTerminalView: ->
    termStatus = $('<li class="term-status"><span class="icon icon-terminal"></span></li>')

    options =
      runCommand    : atom.config.get 'terminal-plus.core.autoRunCommand'
      shellOverride : atom.config.get 'terminal-plus.core.shellOverride'
      shellArguments: atom.config.get 'terminal-plus.core.shellArguments'
      cursorBlink   : atom.config.get 'terminal-plus.toggles.cursorBlink'

    terminalPlusView = new TerminalPlusView(options)
    termStatus.data("terminalView", terminalPlusView)
    terminalPlusView.statusIcon = termStatus
    terminalPlusView.statusBar = this
    @terminalViews.push terminalPlusView

    termStatus.children().click (event) =>
      terminalPlusView.toggle() if event.which is 1
      terminalPlusView.destroy() if event.which is 2
    @statusContainer.append termStatus
    return terminalPlusView

  activeNextTerminalView: ->
    @activeTerminalView @activeIndex + 1

  activePrevTerminalView: ->
    @activeTerminalView @activeIndex - 1

  activeTerminalView: (index) ->
    if index >= @terminalViews.length
      index = 0
    if index < 0
      index = @terminalViews.length - 1
    @terminalViews[index].open() if @terminalViews[index]?

  getActiveTerminalView: () ->
    return @terminalViews[@activeIndex]

  runInActiveView: (callback) ->
    view = @getActiveTerminalView()
    if view?
      return callback(view)
    return null

  runInOpenView: (callback) ->
    view = @getActiveTerminalView()
    if view? and view.hasParent()
      return callback(view)
    return null

  setActiveTerminalView: (terminalView) ->
    @activeIndex = @terminalViews.indexOf terminalView

  removeTerminalView: (terminalView) ->
    index = @terminalViews.indexOf terminalView
    return if index < 0
    @terminalViews.splice index, 1
    @activeIndex-- if index <= @activeIndex and @activeIndex > 0

  moveTerminalView: (oldIndex, newIndex, activeTerminal) =>
    view = @terminalViews.splice(oldIndex, 1)[0]
    @terminalViews.splice newIndex, 0, view
    @setActiveTerminalView activeTerminal

  newTerminalView: ->
    @createTerminalView().toggle()

  attach: () ->
    atom.workspace.addBottomPanel(item: this, priority: 100)

  destroyActiveTerm: ->
    @terminalViews[@activeIndex].destroy() if @terminalViews[@activeIndex]?

  closeAll: ->
    for index in [@terminalViews.length .. 0]
      o = @terminalViews[index]
      if o?
        o.destroy()
    @activeIndex = 0

  destroy: ->
    @subscriptions.dispose()
    for view in @terminalViews
      view.ptyProcess.terminate()
      view.terminal.destroy()
    @detach()

  toggle: ->
    @createTerminalView() unless @terminalViews[@activeIndex]?
    @terminalViews[@activeIndex].toggle()

  setStatusColor: (event) ->
    color = event.type.match(/\w+$/)[0]
    color = atom.config.get("terminal-plus.colors.#{color}").toRGBAString()
    $(event.target).closest('.term-status').css 'color', color

  clearStatusColor: (event) ->
    $(event.target).closest('.term-status').css 'color', ''
