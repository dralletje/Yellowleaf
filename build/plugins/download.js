// YellowLeaf FTP by Michiel Dral 
var download, fs;

fs = require('fs');

download = function() {
  this.on('command.retr', function(file) {
    var fileStream, path;
    path = this.getFullPath(file);
    fileStream = fs.createReadStream(path);
    return this.dataServer.getConnection((function(_this) {
      return function(connection) {
        return fileStream.pipe(connection);
      };
    })(this));
  });
  return this.on('command.stor', function(file) {
    var fileStream, path;
    path = this.getFullPath(file);
    fileStream = fs.createWriteStream(path);
    return this.dataServer.getConnection((function(_this) {
      return function(connection) {
        return connection.pipe(fileStream);
      };
    })(this));
  });
};

module.exports = download;
