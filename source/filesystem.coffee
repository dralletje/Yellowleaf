## Example filesystem

Path = require 'path'
Promise = require 'bluebird'
fs = Promise.promisifyAll require 'fs'
os = require 'os'

rimraf = Promise.promisify require 'rimraf'
mkdirp = Promise.promisify require 'mkdirp'

debug = require('debug')('[Drive]', 'red')

module.exports = class SimpleDrive
  constructor: (directory) ->
    @directory = directory
    @cwd = '/'

  path: (files...) ->
    if not @cwd? then @cwd = '/'
    if not @directory? then @directory = '/'

    file = Path.join files...
    if file.indexOf('/') isnt 0
      file = Path.join @cwd, file
    file = Path.join '/', file

    [
      Path.join @directory, file
      file
    ]


  # Move the CWD
  dir: (moveTo) ->
    if moveTo.indexOf('/') isnt 0
      moveTo = Path.join '/', @cwd, moveTo
    @cwd = moveTo

  stat: (path...) ->
    [fullpath, relativepath] = @path path...

    fs.statAsync(fullpath).then (stat) =>
      paths =
        relpath: relativepath
        fullpath: fullpath
        name: relativepath.match(/\/([^/]*)\/?$/)[1]

      stat.directory = stat.isDirectory()

      if stat.directory
        new Directory this, stat, paths
      else
        new File this, stat, paths


  create: (path...) ->
    [fullpath, relativepath] = @path path...
    mkdirp(Path.dirname(fullpath), {}).then ->
      new Promise (yell, cry) ->
        fs.createWriteStream(fullpath)
          .on 'open', ->
            yell this
          .on 'error', cry

  createDir: (path...) ->
    [fullpath, relativepath] = @path path...
    fs.mkdirAsync fullpath


module.exports.Entity = class Entity
  constructor: (drive, stat, paths) ->
    @isDirectory = stat.directory

    @drive = drive
    @stat = stat
    @paths = paths

    {@relpath, @fullpath, @name} = paths
    #@rights =

  info: ->
    isDirectory: @isDirectory
    name: @name
    path: @relpath
    stat: @stat

  rename: (to) ->
    [fullpath, relativepath] = @drive.path to
    fs.renameAsync(@fullpath, fullpath).then =>
      @drive.stat to

  remove: ->
    rimraf @fullpath

module.exports.Directory = class Directory extends Entity
  list: ->
    fs.readdirAsync(@fullpath).then (entities) =>
      Promise.all entities.map (entity) =>
        @entity(entity)

  entity: (path...) ->
    @drive.stat @relpath, path...


module.exports.File = class File extends Entity
  read: ->
    fs.createReadStream @fullpath

  write: ->
    fs.createWriteStream @fullpath

  modify: (fnOrStream) ->
    now = new Date
    path = [
      os.tmpdir()
      now.getYear(), now.getMonth(), now.getDate()
      '-'
      process.pid
      '-'
      (Math.random() * 0x100000000 + 1).toString(36)
    ].join ''

    new Promise (yell, cry) =>
      @read().pipe(fnOrStream).pipe(fs.createWriteStream path).on('finish', yell)

    .bind(this)
    .then ->
      @remove()

    .then ->
      fs.renameAsync(path, @fullpath)
