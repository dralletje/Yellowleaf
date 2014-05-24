## Example filesystem

path = require 'path'
Promise = require 'bluebird'
fs = Promise.promisifyAll require 'fs'

debug = require('debug')('[Drive]', 'red')

module.exports = class SimpleDrive
  constructor: (directory) ->
    @directory = directory
    @cwd = '/'

  path: (files...) ->
    if not @cwd? then @cwd = '/'
    if not @directory? then @directory = '/'

    file = path.join files...
    if not file.startsWith '/'
      file = path.join @cwd, file
    file = path.join '/', file

    [
      path.join @directory, file
      file
    ]


  # Move the CWD
  dir: (moveTo) ->
    if not moveTo.startsWith '/'
      moveTo = path.join '/', @cwd, moveTo
    @cwd = moveTo

  stat: (path...) ->
    [fullpath, relativepath] = @path path...

    fs.statAsync(fullpath).then (stat) =>
      stat.name = relativepath
      stat.path = fullpath
      stat.directory = stat.isDirectory()

      if stat.directory
        new Directory this, stat
      else
        new File this, stat

  create: (path...) ->
    [fullpath, relativepath] = @path path...
    fs.createWriteStream fullpath

  createDir: (path...) ->
    [fullpath, relativepath] = @path path...
    fs.mkdirAsync fullpath


module.exports.Entity = class Entity
  constructor: (drive, stat) ->
    @isDirectory = stat.directory
    @drive = drive
    @stat = stat

    {@path, @name} = stat
    #@rights =

  rename: (to) ->
    fs.rename @path, to

module.exports.Directory = class Directory extends Entity
  list: ->
    fs.readdirAsync(@path).then (entities) =>
      Promise.all entities.map (entity) =>
        @entity(entity)

  entity: (path...) ->
    @drive.stat @name, path...

  remove: ->
    fs.rmdir @path

module.exports.File = class File extends Entity
  read: ->
    fs.createReadStream @path

  remove: ->
    fs.unlink @path
