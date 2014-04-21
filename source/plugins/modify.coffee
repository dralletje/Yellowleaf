fs = require 'fs'

modify = (basedir) ->
  ## Basic file modification commands
  @on 'command.mkd', (file) ->
    console.log 'Lawl!'
    fs.mkdir @getFullPath(file), () =>
      @write '257 Directory created, at your service.'

  @on 'command.rmd', (file) ->
    fs.rmdir @getFullPath(file), () =>
      @write '250 Directory deleted.'
      #@write '450 Not allowed.'

  @on 'command.dele', (file) ->
    fs.unlink @getFullPath(file), () =>
      @write '250 Directory deleted.'
      #@write '450 Not allowed.'

  ## Rename commands
  @on 'command.rnfr', (file) ->
    @rnfr = @getFullPath file
    @write '350 Will memorize it!'

  @on 'command.rnto', (file) ->
    if not @rnfr? then return @write '500 AND WHERE IS THE RNFR COMMAND?!'
    fs.rename @rnfr, @getFullPath(file)
    @write '250 File teleportation done.'

# for us to do a require later
module.exports = modify
