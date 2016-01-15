# Refactoring status: 100%
globalState = require './global-state'
settings = require './settings'
{CompositeDisposable} = require 'atom'
{toggleClassByCondition} = require './utils'

validNames = /[a-zA-Z*+%_"]/
REGISTERS = /// (
  ?: [a-zA-Z*+%_".]
) ///

# TODO: Vim support following registers.
# x: complete, -: partially
#  [x] 1. The unnamed register ""
#  [ ] 2. 10 numbered registers "0 to "9
#  [ ] 3. The small delete register "-
#  [x] 4. 26 named registers "a to "z or "A to "Z
#  [-] 5. three read-only registers ":, "., "%
#  [ ] 6. alternate buffer register "#
#  [ ] 7. the expression register "=
#  [ ] 8. The selection and drop registers "*, "+ and "~
#  [x] 9. The black hole register "_
#  [ ] 10. Last search pattern register "/

class RegisterManager
  constructor: (@vimState) ->
    {@editor, @editorElement} = @vimState
    @data = globalState.register

  isValid: (name) ->
    REGISTERS.test(name)

  getText: (name) ->
    @get(name).text ? ''

  get: (name) ->
    name ?= @getName()
    name = settings.get('defaultRegister') if name is '"'

    switch name
      when '*', '+'
        text = atom.clipboard.read()
      when '%'
        text = @editor.getURI()
      when '_' # Blackhole always returns nothing
        text = ''
      else
        {text, type} = @data[name.toLowerCase()] ? {}
    type ?= @getCopyType(text ? '')
    {text, type}

  # Private: Sets the value of a given register.
  #
  # name  - The name of the register to fetch.
  # value - The value to set the register to, with following properties.
  #  text: text to save to register.
  #  type: (optional) if ommited automatically set from text.
  #
  # Returns nothing.
  set: (args...) ->
    [name, value] = []
    switch args.length
      when 1 then [value] = args
      when 2 then [name, value] = args

    name ?= @getName()
    return unless @isValid(name)
    name = settings.get('defaultRegister') if name is '"'
    value.type ?= @getCopyType(value.text)

    switch name
      when '*', '+'
        atom.clipboard.write(value.text)
      when '_', '%'
        null
      else
        if /^[A-Z]$/.test(name)
          @append(name.toLowerCase(), value)
        else
          @data[name] = value

  # Private: append a value into a given register
  # like setRegister, but appends the value
  append: (name, value) ->
    unless register = @data[name]
      @data[name] = value
      return

    if 'linewise' in [register.type, value.type]
      if register.type isnt 'linewise'
        register.text += '\n'
        register.type = 'linewise'
      if value.type isnt 'linewise'
        value.text += '\n'
    register.text += value.text

  reset: ->
    @name = null
    @updateEditorElement()

  getName: ->
    @name ? settings.get('defaultRegister')

  setName: ->
    @vimState.hover.add '"'
    @updateEditorElement()
    @vimState.onDidConfirmInput (@name) => @vimState.hover.add(@name)
    @vimState.onDidCancelInput => @vimState.hover.reset()
    @vimState.input.focus({charsMax: 1})

  getCopyType: (text) ->
    if text.lastIndexOf("\n") is text.length - 1
      'linewise'
    else if text.lastIndexOf("\r") is text.length - 1
      'linewise'
    else
      # [FIXME] should characterwise or line and character
      'character'

  updateEditorElement: ->
    toggleClassByCondition(@editorElement, 'with-register', @name?)

module.exports = RegisterManager
