// YellowLeaf FTP by Michiel Dral 
var Directory, Entity, File, Promise, SimpleDrive, debug, fs, path,
  __slice = [].slice,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

path = require('path');

Promise = require('bluebird');

fs = Promise.promisifyAll(require('fs'));

debug = require('debug')('[Drive]', 'red');

module.exports = SimpleDrive = (function() {
  function SimpleDrive(directory) {
    this.directory = directory;
    this.cwd = '/';
  }

  SimpleDrive.prototype.path = function() {
    var file, files;
    files = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    if (this.cwd == null) {
      this.cwd = '/';
    }
    if (this.directory == null) {
      this.directory = '/';
    }
    file = path.join.apply(path, files);
    if (!file.startsWith('/')) {
      file = path.join(this.cwd, file);
    }
    file = path.join('/', file);
    return [path.join(this.directory, file), file];
  };

  SimpleDrive.prototype.dir = function(moveTo) {
    if (!moveTo.startsWith('/')) {
      moveTo = path.join('/', this.cwd, moveTo);
    }
    return this.cwd = moveTo;
  };

  SimpleDrive.prototype.stat = function() {
    var fullpath, path, relativepath, _ref;
    path = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    _ref = this.path.apply(this, path), fullpath = _ref[0], relativepath = _ref[1];
    return fs.statAsync(fullpath).then((function(_this) {
      return function(stat) {
        stat.name = relativepath;
        stat.path = fullpath;
        stat.directory = stat.isDirectory();
        if (stat.directory) {
          return new Directory(_this, stat);
        } else {
          return new File(_this, stat);
        }
      };
    })(this));
  };

  SimpleDrive.prototype.create = function() {
    var fullpath, path, relativepath, _ref;
    path = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    _ref = this.path.apply(this, path), fullpath = _ref[0], relativepath = _ref[1];
    return fs.createWriteStream(fullpath);
  };

  SimpleDrive.prototype.createDir = function() {
    var fullpath, path, relativepath, _ref;
    path = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    _ref = this.path.apply(this, path), fullpath = _ref[0], relativepath = _ref[1];
    return fs.mkdirAsync(fullpath);
  };

  return SimpleDrive;

})();

module.exports.Entity = Entity = (function() {
  function Entity(drive, stat) {
    this.isDirectory = stat.directory;
    this.drive = drive;
    this.stat = stat;
    this.path = stat.path, this.name = stat.name;
  }

  Entity.prototype.rename = function(to) {
    return fs.rename(this.path, to);
  };

  return Entity;

})();

module.exports.Directory = Directory = (function(_super) {
  __extends(Directory, _super);

  function Directory() {
    return Directory.__super__.constructor.apply(this, arguments);
  }

  Directory.prototype.list = function() {
    return fs.readdirAsync(this.path).then((function(_this) {
      return function(entities) {
        return Promise.all(entities.map(function(entity) {
          return _this.entity(entity);
        }));
      };
    })(this));
  };

  Directory.prototype.entity = function() {
    var path, _ref;
    path = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return (_ref = this.drive).stat.apply(_ref, [this.name].concat(__slice.call(path)));
  };

  Directory.prototype.remove = function() {
    return fs.rmdir(this.path);
  };

  return Directory;

})(Entity);

module.exports.File = File = (function(_super) {
  __extends(File, _super);

  function File() {
    return File.__super__.constructor.apply(this, arguments);
  }

  File.prototype.read = function() {
    return fs.createReadStream(this.path);
  };

  File.prototype.remove = function() {
    return fs.unlink(this.path);
  };

  return File;

})(Entity);
