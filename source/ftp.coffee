Ftpd = require 'ftpd'
#polyfill = require "polyfill"
fs = require 'fs'
crypto = require 'crypto'
Promise = require 'bluebird'

## Plugins
filesystemPlugins = [
  require './new-plugins/explorer'
  require './new-plugins/modify'
  require './new-plugins/download'
]

basePlugins = [
  Ftpd.defaults.nonFileCommands
  Ftpd.defaults.dataSocket
  Ftpd.defaults.unknownCommand
]

## Polyfills
#polyfill.extend String, 'startsWith', (searchString, position=0) ->
#  @indexOf(searchString, position) is position

#polyfill.extend Object, 'forEach', (fn, scope) ->
#  for own key, value of this
#    fn.call(scope, value, key, this)



module.exports = (auth) ->
  new Ftpd (client) ->
    client.user = undefined

    ###
    Authentication
    ###
    client.on 'command.user', (user) ->
      @user = user.toLowerCase()
      @write '331 OK'

    client.on 'command.pass', (args...) ->
      password = args.join ' '
      Promise.try(auth, [@user, password]).then (drive) =>
        # Base plugins TODO: Make this more elegant, some way
        basePlugins.forEach (pl) ->
          pl client

        filesystemPlugins.forEach (pl) ->
          pl client, drive

        @Drive = drive
        @write '230 OK.'

      .catch (e) =>
        @write '530 The gates shall not open for you! ('+e.message+')'
        return

    client.on 'error', (e) ->
      console.log 'OOOPS', e.message
      @write '500 Something went wrong, no idea what though.'
