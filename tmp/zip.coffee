archiver = require 'archiver'
unzip = require 'unzip'

archive = archiver 'zip'

archive.on 'error', (err) ->
  console.log "Archiverrrr:\n", err.stack

archive.append 'Struggles',
  name: 'strugg.les'
archive.finalize()

archive.pipe(unzip.Parse())
.on 'entry', (entry) ->
  fileName = entry.path
  type = entry.type # 'Directory' or 'File'
  size = entry.size

  console.log fileName, type, size

  if fileName is "this IS the file I'm looking for"
    entry.autodrain()
  else
    entry.autodrain()
