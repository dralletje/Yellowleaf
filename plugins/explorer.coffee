path = require "path"
polyfill = require "polyfill"
fs = require 'fs'
async = require 'async'
Q = require 'kew'

require 'date'

polyfill.extend Function, 'asPromise', (args...) ->
  defered = Q['defer']()
  @call undefined, args..., defered.makeNodeResolver()
  defered.promise

polyfill.extend Array, 'forEachAsync', (fn) ->
  async.each.asPromise this, fn

explorer = (basedir) ->
  @basedir = basedir or @basedir or throw new Error "No base directory given"

  @on 'command.cwd', (cwd) ->
    if not cwd.startsWith '/'
      cwd = path.join '/', @cwd, cwd
    @cwd = cwd
    @write '250 Ok.'
    
  @on 'command.pwd', () ->
    @write "257 \"#{@cwd}\""
  
  @on 'command.cdup', () ->
    @cwd = path.join @cwd, '../'
    @write "200 Lifted"
    
  @on 'command.nlst', (folder) ->
    promiseFiles = undefined
    connection = undefined
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
      
    .fail (err) ->
      console.log err.stack
    
  @on 'command.list', (file) ->
    asyncFiles = undefined
    asyncResults = undefined
    asyncConnection = undefined
    @fs('readdir', file).then (files) =>
      fullpaths = files.map @getFullPath, this
      asyncFiles = files
      async.map.asPromise fullpaths, fs.stat
      
    .then (results) =>
      results = results.map (value, index) ->
        value.name = asyncFiles[index]
        return value
      
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
      
    .fail (err) =>
      console.error 'In "LIST":', err
      
      if not err.ftpNotified
        @write "550 Can't fly here, this place does not exist"
    .fin () ->
      asyncFiles = undefined
      asyncResults = undefined
      asyncConnection = undefined
            
  @on 'command.size', (file) ->
    file = @getFullPath(@cwd + '/' + file)
    @fs('stat', file).then (stat) ->
      @write "213 " + s.size.getTime()

# for us to do a require later
module.exports = explorer
