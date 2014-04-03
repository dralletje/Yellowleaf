## Example filesystem

path = require 'path'
Promise = require 'bluebird'
fs = Promise.promisifyAll require 'fs'

Drive = require './drive'

module.exports = class SimpleDrive extends Drive
  constructor: (directory) ->
    @directory = directory
    @cwd = '/'

  # Move the CWD
  dir: (moveTo) ->
    if not moveTo.startsWith '/'
      moveTo = path.join '/', @cwd, moveTo
    @cwd = moveTo

  stat: (path) ->
    fullpath = @path path
    fs.statAsync().then (stat) =>
      stat.name = path
      stat.path = fullpath

      if stat.isDirectory()
        new Directory this, stat
      else
        new File this, stat

  # Directory commands
  xxx: (dir) ->
    dir = @path dir
    fs.readdirAsync(dir).then (files) ->
      asyncFiles = files
      Promise.all files.map (file) =>
        fs.statAsync @path file

    .then (stats) ->
      console.log stats

module.exports.Entity = class Entity
  constructor: (drive, path, stat) ->
    @drive = drive
    @path = path
    @stat = stat

    console.log this

module.exports.Directory = class Directory extends Entity
  list: () ->
    fs.readdirAsync(@path).then (entities) ->
      console.log 'entities:', entities
      entities

module.exports.File = class File extends Entity
