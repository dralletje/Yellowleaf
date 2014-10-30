## Example filesystem

Path = require 'path'
Promise = require 'bluebird'
fs = Promise.promisifyAll require 'fs'
os = require 'os'

rimraf = Promise.promisify require 'rimraf'
mkdirp = Promise.promisify require 'mkdirp'
_ = require 'lodash'

class Nope extends Error

module.exports = class JoinedDrive
  constructor: (drives) ->
    @drives = drives
    @cwd = '/'

  path: (files...) ->
    if not @cwd? then @cwd = '/'

    file = Path.join files...
    if file.indexOf('/') isnt 0
      file = Path.join @cwd, file
    Path.join '/', file

  # Move the CWD
  dir: (moveTo) ->
    if moveTo.indexOf('/') isnt 0
      moveTo = Path.join '/', @cwd, moveTo
    @cwd = moveTo

  stat: (paths...) ->
    path = @path path...
    [drive, file] = @DriveByPath path

    if typeof file is 'string'
      return drive.stat file

    Promise.resolve new JoinedDirectory drive, path, file




  create: (paths...) ->
    path = @path path...
    [drive, file] = @DriveByPath path

    if typeof extra isnt 'string'
      # Can't edit
      throw new Error 'ReadOnly'
    # Pass it on to the drive
    drive.create file


  createDir: (path...) ->
    path = @path path...
    [drive, file] = @DriveByPath path

    if typeof extra isnt 'string'
      # Can't edit
      throw new Error 'ReadOnly'
    # Pass it on to the drive
    drive.createDir file


  DriveByPath: (p) ->
    p = p.replace(/\[(\w+)\]/g, '.$1') # Convert [anything] to .anything
    p = p.replace('/', '.')
    p = p.replace(/^\./, '') # Strip leading dot
    a = p.split '.'

    o = @drives

    # Track down the path
    ParentDrive = null
    while a.length
      n = a.shift()
      if n is ''
        continue

      # If there is no sub-drive
      if not o.hasOwnProperty(n)
        # If we already dove into another Drive, use it.
        if ParentDrive?
          # Return a resource from that drive
          return [ParentDrive, "/#{n}/#{a.join '/'}"]
        else
          # If not... 404!! :-D
          throw new Error 'File does not exist ('+p+'), I\'m sorry'

      o = o[n]
      # If we end up AT a drive, dive into that.
      if o.stat?
        return [o, a.join '/']

      # When it has a parentdrive contained, set it.
      if o['/']?.stat?
        ParentDrive = o['/']

    # If we followed the whole path, but we are not on an end yet,
    # List the file where we are now.
    n = _(o).pairs().filter((t, key) -> key isnt '/').object().value()
    [ParentDrive, n]


# Directory composed from another drive's directory and your own file list
module.exports.JoinedDirectory = class JoinedDirectory
  constructor: (drive, path, files) ->
    @drive = drive
    @stat = {}
    @files = files

    @size = 1
    @relpath = @name = path

  isDirectory: yes
  info: ->
    isDirectory: @isDirectory
    name: @name
    path: @relpath

  rename: (to) ->
    throw new Nope
  remove: ->
    throw new Nope

  list: ->
    if @drive?
      @drive.stat('/').then (ent) ->
        ent.list()
      .then (list) =>
        console.log list
        list
    else
      console.log 'Hi:', @files
      Promise.map _.pairs(@files), (t) ->
        [folder, drive] = t
        drive = drive.stat('/')
        return [folder, drive]
      .then (list) ->
        list = _.object list
        console.log list

  listDeep: ->
    @list().map (entity) ->
      if not entity.isDirectory
        return entity

      # If the entity is a directory
      # Get his listing and add the directory to it
      list = entity.listDeep()
      list.push(entity)
      return list
    .then(_.flatten)
    .map (entity) =>
      entity.relpath = entity.relpath.slice @relpath.length
      entity


  entity: (path...) ->
    @drive.stat @relpath, path...
