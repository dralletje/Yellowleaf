// YellowLeaf FTP by Michiel Dral 
var Drive, ftp, server;

ftp = require('./ftp');

Drive = require('./filesystem');

server = ftp(function(user, password) {
  if (user === 'jelle' && password === 'jelle') {
    return new Drive(process.cwd() + "/test/example/ftp");
  }
}).listen(8021);
