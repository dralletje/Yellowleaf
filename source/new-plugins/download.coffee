Promise = require 'bluebird'

download = (drive) ->
  ## Upload and download
  @on 'command.retr', (path) ->
    Promise.all([
      drive.stat(path)
    , @dataServer.getConnection()
    ]).spread (file, connection) ->
      file.read().pipe connection

  @on 'command.stor', (path) ->
    Promise.all([
      drive.create(path)
    , @dataServer.getConnection()
    ]).spread (file, connection) ->
      connection.pipe file

# for us to do a require later
module.exports = download
