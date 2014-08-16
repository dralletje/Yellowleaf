// YellowLeaf FTP by Michiel Dral 
var Promise, download;

Promise = require('bluebird');

download = function(ftp, drive) {
  ftp.on('command.retr', function(path) {
    return Promise.all([drive.stat(path), this.dataServer.getConnection()]).spread(function(file, connection) {
      return file.read().pipe(connection);
    });
  });
  return ftp.on('command.stor', function(path) {
    return Promise.all([drive.create(path), this.dataServer.getConnection()]).spread(function(file, connection) {
      return connection.pipe(file);
    });
  });
};

module.exports = download;
