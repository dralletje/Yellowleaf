Ftpd = require 'ftpd'
#polyfill = require "polyfill"
fs = require 'fs'
crypto = require 'crypto'
Promise = require 'bluebird'

## Plugins
p =
  explorer  : require './new-plugins/explorer'
  modify    : require './new-plugins/modify'
  download  : require './new-plugins/download'
  dataSocket: Ftpd.defaults.dataSocket
  unknownCommand: Ftpd.defaults.unknownCommand

## Polyfills
#polyfill.extend String, 'startsWith', (searchString, position=0) ->
#  @indexOf(searchString, position) is position

#polyfill.extend Object, 'forEach', (fn, scope) ->
#  for own key, value of this
#    fn.call(scope, value, key, this)

standardReplies =
  feat: '500 Go away'
  syst: '215 UNIX Type: L8'
  quit: '221 See ya.'
  noop: '200 OK.'
  site: '500 Go away'

module.exports = (auth, port=21) ->
  server = new Ftpd () ->
    @mode = "ascii"
    @user = undefined

    ###
    Authentication
    ###
    @on 'command.user', (user) ->
      @user = user.toLowerCase()
      @write '331 OK'

    @on 'command.pass', (args...) ->
      password = args.join ' '
      Promise.try(auth, [@user, password]).then (drive) =>
        @Drive = drive
        @write '230 OK.'
        [p.explorer, p.modify, p.download, p.dataSocket, p.unknownCommand].forEach (pl) =>
          pl.call this, @Drive

      .catch (e) =>
        @write '530 The gates shall not open for you! ('+e.message+')'
        return

    ###
    Type and opts.. and maybe more like it later
    ###
    @on 'command.type', (modechar) ->
      if modechar is 'I'
        @mode = null
      else if modechar is 'A'
        @mode = "ascii"
      @write '200 Custom mode activated'

    @on 'command.opts', (opt) ->
        if opt.toUpperCase() is 'UTF8 ON'
          @write '200 Yo, cool with that!'
          return

        @write '504 Sorry, I don\'t know how to handle this.'
        console.log 'Unknown OPTS:', opt

    ## Nonsense commands
    for key, response of standardReplies
      @on "command.#{key}", ((value) ->
        @write value
      ).bind this, response

    @on 'error', (e) ->
      console.log 'OOOPS', e.message
      @write '500 Something went wrong, no idea what though.'

  .listen(port)
  .on 'error', (e) ->
    console.log e.message
    process.exit 0
