Ftpd = require 'ftpd'
polyfill = require "polyfill"
fs = require 'fs'
crypto = require 'crypto'

## Plugins
p =
  explorer  : require './plugins/explorer'
  modify    : require './plugins/modify'
  download  : require './plugins/download'
  dataSocket: Ftpd.defaults.dataSocket
  unknownCommand: Ftpd.defaults.unknownCommand

## Polyfills
polyfill.extend String, 'startsWith', (searchString, position=0) ->
  @indexOf(searchString, position) is position

polyfill.extend Object, 'forEach', (fn, scope) ->
  for own key, value of this
    fn.call(scope, value, key, this)

## Mongo
mongojs  = require 'mongojs'
db = mongojs('secretary', ['clients']);

standardReplies =
  feat: '500 Go away'
  syst: '215 UNIX Type: L8'
  quit: '221 See ya.'
  noop: '200 OK.'
  site: '500 Go away'

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
    #hash = crypto.createHash 'sha512'
    #hash.write password
    #hash.end()
    #digest = hash.read().toString('hex')
    console.log "Authenticating '#{@user}'"
    
    if @user isnt 'plancke' or password isnt 'eff60fc8'
      @write '530 The gates shall not open for you!'
      return #@end()
        
    @write '230 OK.'
    p.explorer.call this, __dirname + "/../../"
    [p.modify, p.download, p.dataSocket, p.unknownCommand].forEach (pl) =>
      pl.call this
    
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
  standardReplies.forEach (value, key) =>
    @on "command.#{key}", () ->
      @write value
      
  @on 'error', (e) ->
    console.log 'OOOPS', e.message
    @write '500 Something went wrong, no idea what though.'
    
.listen(23)
.on 'error', (e) ->
  console.log e.message
  process.exit 0
