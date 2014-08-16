// YellowLeaf FTP by Michiel Dral 
var Promise, debug, explorer;

Promise = require('bluebird');

require('date');

debug = function() {};

explorer = function(drive) {
  this.on('command.cwd', function(cwd) {
    drive.dir(cwd);
    return this.write('250 Ok.');
  });
  this.on('command.pwd', function() {
    debug(drive);
    return this.write("257 \"" + drive.cwd + "\"");
  });
  this.on('command.cdup', function() {
    drive.dir('../');
    return this.write("200 Lifted");
  });
  this.on('command.nlst', function(folder) {
    return Promise.all([
      drive.stat(folder).then(function(directory) {
        return directory.list();
      }), this.dataServer.getConnection()
    ]).spread((function(_this) {
      return function(files, connection) {
        files = files.map(function(file) {
          return file.slice(1);
        }).map(function(file) {
          return file + "\r\n";
        });
        debug(_this.files);
        return connection.write(_this.files.join(""));
      };
    })(this)).then((function(_this) {
      return function() {
        _this.dataServer.sayGoodbye().end();
        return debug('Done!');
      };
    })(this))["catch"](function(err) {
      return debug(err.stack);
    });
  });
  this.on('command.list', function(folder) {
    return Promise.all([
      drive.stat(folder).then(function(directory) {
        return directory.list();
      }), this.dataServer.getConnection()
    ]).spread(function(results, connection) {
      return Promise.all(results.map(function(entity) {
        return new Promise(function(resolve, reject) {
          var line;
          line = entity.isDirectory ? 'd' : '-';
          line += 'rwxrwxrwx';
          line += " 1 ftp ftp ";
          line += entity.stat.size.toString();
          line += new Date(entity.stat.mtime).format(' M d H:i ');
          line += (function() {
            var name;
            name = entity.name.split('/');
            return name[name.length - 1];
          })();
          return connection.writeLn(line, resolve);
        });
      }));
    }).then((function(_this) {
      return function() {
        return _this.dataServer.sayGoodbye().end();
      };
    })(this))["catch"]((function(_this) {
      return function(err) {
        console.error('In "LIST":', err.stack);
        if (!err.ftpNotified) {
          return _this.write("550 Can't fly here, this place does not exist");
        }
      };
    })(this));
  });
  return this.on('command.size', function(path) {
    return drive.stat(path).then(function(file) {
      return this.write("213 " + file.stat.size.getTime());
    });
  });
};

module.exports = explorer;
