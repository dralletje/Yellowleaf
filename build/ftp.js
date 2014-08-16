// YellowLeaf FTP by Michiel Dral 
var Ftpd, Promise, crypto, fs, p, standardReplies,
  __slice = [].slice;

Ftpd = require('ftpd');

fs = require('fs');

crypto = require('crypto');

Promise = require('bluebird');

p = {
  explorer: require('./new-plugins/explorer'),
  modify: require('./new-plugins/modify'),
  download: require('./new-plugins/download'),
  dataSocket: Ftpd.defaults.dataSocket,
  unknownCommand: Ftpd.defaults.unknownCommand
};

standardReplies = {
  feat: '500 Go away',
  syst: '215 UNIX Type: L8',
  quit: '221 See ya.',
  noop: '200 OK.',
  site: '500 Go away'
};

module.exports = function(auth) {
  return new Ftpd(function(client) {
    var key, response;
    client.mode = "ascii";
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
          return [p.explorer, p.modify, p.download, p.dataSocket, p.unknownCommand].forEach(function(pl) {
            return pl(_this, _this.Drive);
          });
        };
      })(this))["catch"]((function(_this) {
        return function(e) {
          _this.write('530 The gates shall not open for you! (' + e.message + ')');
        };
      })(this));
    });

    /*
    Type and opts.. and maybe more like it later
     */
    client.on('command.type', function(modechar) {
      if (modechar === 'I') {
        this.mode = null;
      } else if (modechar === 'A') {
        this.mode = "ascii";
      }
      return this.write('200 Custom mode activated');
    });
    client.on('command.opts', function(opt) {
      if (opt.toUpperCase() === 'UTF8 ON') {
        this.write('200 Yo, cool with that!');
        return;
      }
      this.write('504 Sorry, I don\'t know how to handle this.');
      return console.log('Unknown OPTS:', opt);
    });
    for (key in standardReplies) {
      response = standardReplies[key];
      client.on("command." + key, (function(value) {
        return this.write(value);
      }).bind(client, response));
    }
    return client.on('error', function(e) {
      console.log('OOOPS', e.message);
      return this.write('500 Something went wrong, no idea what though.');
    });
  });
};
