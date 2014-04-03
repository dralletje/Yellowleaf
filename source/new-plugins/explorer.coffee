polyfill = require "polyfill"

Promise = require 'bluebird'
async = Promise.promisifyAll require 'async'

require 'date'

polyfill.extend Array, 'forEachAsync', (fn) ->
  async.eachAsync this, fn

explorer = (drive) ->
  @on 'command.cwd', (cwd) ->
    drive.dir cwd
    @write '250 Ok.'

  @on 'command.pwd', () ->
    console.log drive
    @write "257 \"#{drive.cwd}\""

  @on 'command.cdup', () ->
    drive.dir '../'
    @write "200 Lifted"

  @on 'command.nlst', (folder) ->
    promiseFiles = undefined
    connection = undefined

    drive.stat(folder).then () ->


    @fs('readdir', folder).then (files) =>
      files = files
      .map(@getFullPath)
      .map (file) ->
        file.slice 1
      .map (file) ->
        file + "\r\n"
      promiseFiles = files
      @dataServer.getConnection()

    .then (connection) ->
      console.log promiseFiles
      connection.write promiseFiles.join ""

    .then () =>
      @dataServer.sayGoodbye().end()
      console.log 'Done!'

    .catch (err) ->
      console.log err.stack

  @on 'command.list', (folder) ->
    asyncFiles = undefined
    asyncResults = undefined
    asyncConnection = undefined

    drive.stat(folder).then (directory) ->
      directory.list()

    .then (results) ->
      asyncResults = results
      console.log 'Connection getting'
      @dataServer.getConnection()

    .then (connection) ->
      asyncConnection = connection
      asyncResults.forEachAsync (stat, cb) ->
        line = if stat.isDirectory() then 'd' else '-'
        line += 'rwxrwxrwx'
        line += " 1 ftp ftp "
        line += stat.size.toString()
        line += new Date(stat.mtime).format(' M d H:i ')
        line += stat.name

        connection.writeLn line, cb
    .then () =>
      @dataServer.sayGoodbye().end()

    .catch (err) =>
      console.error 'In "LIST":', err

      if not err.ftpNotified
        @write "550 Can't fly here, this place does not exist"
    .finally () ->
      asyncFiles = undefined
      asyncResults = undefined
      asyncConnection = undefined

  @on 'command.size', (file) ->
    file = @getFullPath(@cwd + '/' + file)
    @fs('stat', file).then (stat) ->
      @write "213 " + s.size.getTime()

# for us to do a require later
module.exports = explorer
