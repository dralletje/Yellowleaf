## Basic helpers for a Drive

path = require 'path'

module.exports = class Drive
  path: (files...) ->
    if not @cwd? then @cwd = '/'
    if not @directory? then @directory = '/'

    file = path.join '/', files...
    if not file.startsWith '/'
      file = path.join @cwd, file
    path.join @directory, file
