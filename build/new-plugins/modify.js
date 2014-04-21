// YellowLeaf FTP by Michiel Dral 
var fs, modify;

fs = require('fs');

modify = function(drive) {
  this.on('command.mkd', function(file) {
    return drive.createDir(file).then((function(_this) {
      return function() {
        return _this.write('257 Directory created, at your service.');
      };
    })(this))["catch"]((function(_this) {
      return function(err) {
        console.log(err.stack);
        return _this.write('450 Shit happens');
      };
    })(this));
  });
  this.on('command.rmd', function(path) {
    return drive.stat(path).then((function(_this) {
      return function(file) {
        file.remove();
        return _this.write('250 Directory deleted.');
      };
    })(this))["catch"](function(error) {
      console.log(error.stack);
      return this.write('450 Not allowed.');
    });
  });
  this.on('command.dele', function(path) {
    return drive.stat(path).then((function(_this) {
      return function(file) {
        file.remove();
        return _this.write('250 File deleted.');
      };
    })(this))["catch"](function(error) {
      console.log(error.stack);
      return this.write('450 Not allowed.');
    });
  });
  this.on('command.rnfr', function(path) {
    this.rnfr = path;
    return this.write('350 Will memorize it!');
  });
  return this.on('command.rnto', function(path) {
    if (this.rnfr == null) {
      return this.write('500 AND WHERE IS THE RNFR COMMAND?!');
    }
    return drive.stat(this.rnfr).then((function(_this) {
      return function(file) {
        file.rename(drive.path(path)[0]);
        return _this.write('250 File teleportation done.');
      };
    })(this))["catch"]((function(_this) {
      return function(error) {
        console.log(error.stack);
        return _this.write('450 Oops!');
      };
    })(this));
  });
};

module.exports = modify;
