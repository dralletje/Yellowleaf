polyfill = require "polyfill"

Promise = require 'bluebird'
async = Promise.promisifyAll require 'async'

require 'date'

polyfill.extend Array, 'forEachAsync', (fn) ->
  async.eachAsync this, fn

#debug = require('debug')('[Exp]', 'magenta')
debug = ->

explorer = (drive) ->
  @on 'command.cwd', (cwd) ->
    drive.dir cwd
    @write '250 Ok.'

  @on 'command.pwd', () ->
    debug drive
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
      debug promiseFiles
      connection.write promiseFiles.join ""

    .then () =>
      @dataServer.sayGoodbye().end()
      debug 'Done!'

    .catch (err) ->
      debug err.stack

  @on 'command.list', (folder) ->
    Promise.all([
      drive.stat(folder).then (directory) ->
        directory.list()
    ,
      @dataServer.getConnection()
    ])
    .spread (results, connection) ->
      Promise.all results.map (entity) ->
        new Promise (resolve, reject) ->
          line = if entity.stat.isDirectory() then 'd' else '-'
          line += 'rwxrwxrwx'
          line += " 1 ftp ftp "
          line += entity.stat.size.toString()
          line += new Date(entity.stat.mtime).format(' M d H:i ')
          line += do () ->
            name = entity.stat.name.split('/')
            name[name.length - 1]

          connection.writeLn line, resolve
    .then () =>
      @dataServer.sayGoodbye().end()
    .catch (err) =>
      console.error 'In "LIST":', err.stack

      if not err.ftpNotified
        @write "550 Can't fly here, this place does not exist"

  @on 'command.size', (path) ->
    drive.stat(path).then (file) ->
      @write "213 " + file.stat.size.getTime()

# for us to do a require later
module.exports = explorer
