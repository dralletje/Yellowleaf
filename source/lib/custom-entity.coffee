# A class to quickly make an entity from a stream

exports.File = class CustomFile
  constructor: (stream) ->
    @stream = stream

  read: ->
    @stream

  isDirectory: false
