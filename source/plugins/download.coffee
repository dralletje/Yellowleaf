fs = require 'fs'

download = () ->
  ## Upload and download
  @on 'command.retr', (file) ->
    path = @getFullPath file
    fileStream = fs.createReadStream path
    @dataServer.getConnection (connection) =>
      fileStream.pipe connection
      
  @on 'command.stor', (file) ->
    path = @getFullPath file
    fileStream = fs.createWriteStream path
    @dataServer.getConnection (connection) =>
      connection.pipe fileStream

# for us to do a require later
module.exports = download
