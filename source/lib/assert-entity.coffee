# A wrapper around the default entity for asserts

module.exports = class AssertEntity
  constructor: (entity) ->
    @entity = entity

  isDirectory: ->
    if not @entity.isDirectory
      throw new Error "Cannot apply to a regular file."

  isFile: ->
    if @entity.isDirectory
      throw new Error "Cannot apply to a directory."
