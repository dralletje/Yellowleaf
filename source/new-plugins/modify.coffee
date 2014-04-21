fs = require 'fs'

modify = (drive) ->
  ## Basic file modification commands
  @on 'command.mkd', (file) ->
    drive.createDir(file).then =>
      @write '257 Directory created, at your service.'
    .catch (err) =>
      console.log err.stack
      @write '450 Shit happens'

  @on 'command.rmd', (path) ->
    drive.stat(path).then (file) =>
      file.remove()
      @write '250 Directory deleted.'
    .catch (error) ->
      console.log error.stack
      @write '450 Not allowed.'

  @on 'command.dele', (path) ->
    drive.stat(path).then (file) =>
      file.remove()
      @write '250 File deleted.'
    .catch (error) ->
      console.log error.stack
      @write '450 Not allowed.'

  ## Rename commands
  @on 'command.rnfr', (path) ->
    @rnfr = path
    @write '350 Will memorize it!'

  @on 'command.rnto', (path) ->
    if not @rnfr?
      return @write '500 AND WHERE IS THE RNFR COMMAND?!'
    drive.stat(@rnfr).then (file) =>
      file.rename drive.path(path)[0]
      @write '250 File teleportation done.'
    .catch (error) =>
      console.log error.stack
      @write '450 Oops!'

# for us to do a require later
module.exports = modify
