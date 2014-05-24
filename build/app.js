// YellowLeaf FTP by Michiel Dral 
var Drive, ftp, rest;

ftp = require('./ftp');

rest = require('./rest');

Drive = require('./filesystem');

module.exports = function(ftpport, webport) {
  var server;
  if (ftpport != null) {
    server = ftp(function(user, password) {
      if (user === 'jelle' && password === 'jelle') {
        return new Drive(process.cwd() + "/test/example");
      }
    }, ftpport);
    console.log('FTP listening on', ftpport);
  }
  if (webport != null) {
    console.log('Web?!');
  }
  return function() {
    if (server != null) {
      return server.close();
    }
  };
};

if (module.parent == null) {
  module.exports(8021);
}
