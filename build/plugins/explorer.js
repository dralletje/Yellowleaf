// YellowLeaf FTP by Michiel Dral 
var Promise, async, explorer, fs, path, polyfill;

path = require("path");

polyfill = require("polyfill");

fs = require('fs');

Promise = require('bluebird');

async = Promise.promisifyAll(require('async'));

require('date');

polyfill.extend(Array, 'forEachAsync', function(fn) {
  return async.eachAsync(this, fn);
});

explorer = function(basedir) {
  this.basedir = basedir || this.basedir || (function() {
    throw new Error("No base directory given");
  })();
  this.on('command.cwd', function(cwd) {
    if (!cwd.startsWith('/')) {
      cwd = path.join('/', this.cwd, cwd);
    }
    this.cwd = cwd;
    return this.write('250 Ok.');
  });
  this.on('command.pwd', function() {
    return this.write("257 \"" + this.cwd + "\"");
  });
  this.on('command.cdup', function() {
    this.cwd = path.join(this.cwd, '../');
    return this.write("200 Lifted");
  });
  this.on('command.nlst', function(folder) {
    var connection, promiseFiles;
    promiseFiles = void 0;
    connection = void 0;
    return this.fs('readdir', folder).then((function(_this) {
      return function(files) {
        files = files.map(_this.getFullPath).map(function(file) {
          return file.slice(1);
        }).map(function(file) {
          return file + "\r\n";
        });
        promiseFiles = files;
        return _this.dataServer.getConnection();
      };
    })(this)).then(function(connection) {
      console.log(promiseFiles);
      return connection.write(promiseFiles.join(""));
    }).then((function(_this) {
      return function() {
        _this.dataServer.sayGoodbye().end();
        return console.log('Done!');
      };
    })(this)).fail(function(err) {
      return console.log(err.stack);
    });
  });
  this.on('command.list', function(file) {
    var asyncConnection, asyncFiles, asyncResults;
    asyncFiles = void 0;
    asyncResults = void 0;
    asyncConnection = void 0;
    return this.fs('readdir', file).then((function(_this) {
      return function(files) {
        var fullpaths;
        fullpaths = files.map(_this.getFullPath, _this);
        asyncFiles = files;
        return async.mapAsync(fullpaths, fs.stat);
      };
    })(this)).then((function(_this) {
      return function(results) {
        results = results.map(function(value, index) {
          value.name = asyncFiles[index];
          return value;
        });
        asyncResults = results;
        console.log('Connection getting');
        return _this.dataServer.getConnection();
      };
    })(this)).then(function(connection) {
      asyncConnection = connection;
      return asyncResults.forEachAsync(function(stat, cb) {
        var line;
        line = stat.isDirectory() ? 'd' : '-';
        line += 'rwxrwxrwx';
        line += " 1 ftp ftp ";
        line += stat.size.toString();
        line += new Date(stat.mtime).format(' M d H:i ');
        line += stat.name;
        return connection.writeLn(line, cb);
      });
    }).then((function(_this) {
      return function() {
        return _this.dataServer.sayGoodbye().end();
      };
    })(this))["catch"]((function(_this) {
      return function(err) {
        console.error('In "LIST":', err);
        if (!err.ftpNotified) {
          return _this.write("550 Can't fly here, this place does not exist");
        }
      };
    })(this))["finally"](function() {
      asyncFiles = void 0;
      asyncResults = void 0;
      return asyncConnection = void 0;
    });
  });
  return this.on('command.size', function(file) {
    file = this.getFullPath(this.cwd + '/' + file);
    return this.fs('stat', file).then(function(stat) {
      return this.write("213 " + s.size.getTime());
    });
  });
};

module.exports = explorer;
