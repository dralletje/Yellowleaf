// YellowLeaf FTP by Michiel Dral 
var fs, modify;

fs = require('fs');

modify = function(basedir) {
  this.on('command.mkd', function(file) {
    console.log('Lawl!');
    return fs.mkdir(this.getFullPath(file), (function(_this) {
      return function() {
        return _this.write('257 Directory created, at your service.');
      };
    })(this));
  });
  this.on('command.rmd', function(file) {
    return fs.rmdir(this.getFullPath(file), (function(_this) {
      return function() {
        return _this.write('250 Directory deleted.');
      };
    })(this));
  });
  this.on('command.dele', function(file) {
    return fs.unlink(this.getFullPath(file), (function(_this) {
      return function() {
        return _this.write('250 Directory deleted.');
      };
    })(this));
  });
  this.on('command.rnfr', function(file) {
    this.rnfr = this.getFullPath(file);
    return this.write('350 Will memorize it!');
  });
  return this.on('command.rnto', function(file) {
    if (this.rnfr == null) {
      return this.write('500 AND WHERE IS THE RNFR COMMAND?!');
    }
    fs.rename(this.rnfr, this.getFullPath(file));
    return this.write('250 File teleportation done.');
  });
};

module.exports = modify;
