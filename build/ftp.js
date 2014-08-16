// YellowLeaf FTP by Michiel Dral 
var Ftpd, Promise, crypto, fs, plugins,
  __slice = [].slice;

Ftpd = require('ftpd');

fs = require('fs');

crypto = require('crypto');

Promise = require('bluebird');

plugins = [require('./new-plugins/explorer'), require('./new-plugins/modify'), require('./new-plugins/download'), Ftpd.defaults.nonFileCommands, Ftpd.defaults.dataSocket, Ftpd.defaults.unknownCommand];

module.exports = function(auth) {
  return new Ftpd(function(client) {
    client.user = void 0;

    /*
    Authentication
     */
    client.on('command.user', function(user) {
      this.user = user.toLowerCase();
      return this.write('331 OK');
    });
    client.on('command.pass', function() {
      var args, password;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      password = args.join(' ');
      return Promise["try"](auth, [this.user, password]).then((function(_this) {
        return function(drive) {
          _this.Drive = drive;
          _this.write('230 OK.');
          return plugins.forEach(function(pl) {
            return pl(_this, _this.Drive);
          });
        };
      })(this))["catch"]((function(_this) {
        return function(e) {
          _this.write('530 The gates shall not open for you! (' + e.message + ')');
        };
      })(this));
    });
    return client.on('error', function(e) {
      console.log('OOOPS', e.message);
      return this.write('500 Something went wrong, no idea what though.');
    });
  });
};
