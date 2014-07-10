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
    if file.indexOf('/') isnt 0
      file = path.join @cwd, file
    file = path.join '/', file

    [
      path.join @directory, file
      file
    ]


  # Move the CWD
  dir: (moveTo) ->
    if moveTo.indexOf('/') isnt 0
      moveTo = path.join '/', @cwd, moveTo
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
    new Promise (yell, cry) ->
      fs.createWriteStream(fullpath)
        .on 'open', ->
          yell this
        .on('error', cry)

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

module.exports.Directory = class Directory extends Entity
  list: ->
    fs.readdirAsync(@fullpath).then (entities) =>
      Promise.all entities.map (entity) =>
        @entity(entity)

  entity: (path...) ->
    @drive.stat @relpath, path...

  remove: ->
    fs.rmdirAsync @fullpath

module.exports.File = class File extends Entity
  read: ->
    fs.createReadStream @fullpath

  remove: ->
    fs.unlinkAsync @fullpath
