archiver = require 'archiver'

{File, Directory} = require '../lib/custom-entity'
{PassThrough} = require 'readable-stream'

# Directory -> File
module.exports.zip = (entity, assert) ->
  assert.isDirectory()

  entity.listDeep(relative: true).then (list) ->
    pass = new PassThrough
    archive = archiver 'zip'

    archive.pipe pass
    archive.on 'error', (err) ->
      console.log "Archiverrrr:\n", err.stack

    list.forEach (file) ->
      archive.append file.read(),
        name: file.relpath.slice(1)
        store: true

    #archive.append(list[0].read(), name: list[0].relpath.slice(1))
    archive.finalize()

    new File pass
