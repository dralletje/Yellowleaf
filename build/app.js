// YellowLeaf FTP by Michiel Dral 
var main, port, server;

main = require('./main');

port = Math.round(Math.random() * 100000);

server = main(function(user, password) {
  if (user === 'jelle' && password === 'jelle') {
    return "test/example";
  }
}, port);

console.log('Listening on', port);
