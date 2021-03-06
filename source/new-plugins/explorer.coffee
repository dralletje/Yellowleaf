Promise = require 'bluebird'

require 'date'

#debug = require('debug')('[Exp]', 'magenta')
debug = ->

explorer = (ftp, drive) ->
  ftp.on 'command.cwd', (cwd) ->
    drive.dir cwd
    @write '250 Ok.'


  ftp.on 'command.pwd', () ->
    debug drive
    @write "257 \"#{drive.cwd}\""


  ftp.on 'command.cdup', () ->
    drive.dir '../'
    @write "200 Lifted"


  # FIXME: Fix this, it is just not working..
  ftp.on 'command.nlst', (folder) ->
    Promise.all([
      drive.stat(folder).then (directory) ->
        directory.list()
    ,
      @dataServer.getConnection()
    ]).spread (files, connection) ->
      files = files
      .map (file) ->
        file.slice 1
      .map (file) ->
        file + "\r\n"

      debug @files
      connection.write @files.join ""
    .then =>
      @dataServer.sayGoodbye().end()
      debug 'Done!'
    .catch (err) ->
      debug err.stack


  ftp.on 'command.list', (folder) ->
    Promise.all([
      drive.stat(folder).catch (err) ->
        drive.createDir(folder).then ->
          drive.stat(folder)
      .then (directory) ->
        directory.list()
    ,
      @dataServer.getConnection()
    ])
    .spread (results, connection) ->
      Promise.all results.map (entity) ->
        new Promise (resolve, reject) ->
          line = if entity.isDirectory then 'd' else '-'
          line += 'rwxrwxrwx'
          line += " 1 ftp ftp "
          line += entity.size.toString()
          # if mtime is undefined it will use the current time (good!)
          line += new Date(entity.stat.mtime).format(' M d H:i ')
          line += do () ->
            name = entity.name.split('/')
            name[name.length - 1]

          connection.writeLn line, resolve
    .then =>
      @dataServer.sayGoodbye().end()
    .catch (err) =>
      console.error 'In "LIST":', err.stack
      if not err.ftpNotified
        @write "550 Can't fly here, this place does not exist"


  ftp.on 'command.size', (path) ->
    drive.stat(path).then (file) ->
      @write "213 " + file.stat.size.getTime()

# for us to do a require later
module.exports = explorer
