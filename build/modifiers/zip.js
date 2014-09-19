// YellowLeaf FTP by Michiel Dral 
var Directory, File, PassThrough, archiver, _ref;

archiver = require('archiver');

_ref = require('../lib/custom-entity'), File = _ref.File, Directory = _ref.Directory;

PassThrough = require('readable-stream').PassThrough;

module.exports.zip = function(entity, assert) {
  assert.isDirectory();
  return entity.listDeep({
    relative: true
  }).then(function(list) {
    var archive, pass;
    pass = new PassThrough;
    archive = archiver('zip');
    archive.pipe(pass);
    archive.on('error', function(err) {
      return console.log("Archiverrrr:\n", err.stack);
    });
    list.forEach(function(file) {
      return archive.append(file.read(), {
        name: file.relpath.slice(1),
        store: true
      });
    });
    archive.finalize();
    return new File(pass);
  });
};
