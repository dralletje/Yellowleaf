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
    if (file.indexOf('/') !== 0) {
      file = path.join(this.cwd, file);
    }
    file = path.join('/', file);
    return [path.join(this.directory, file), file];
  };

  SimpleDrive.prototype.dir = function(moveTo) {
    if (moveTo.indexOf('/') !== 0) {
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
        var paths;
        paths = {
          relpath: relativepath,
          fullpath: fullpath,
          name: relativepath.match(/\/([^/]*)\/?$/)[1]
        };
        stat.directory = stat.isDirectory();
        if (stat.directory) {
          return new Directory(_this, stat, paths);
        } else {
          return new File(_this, stat, paths);
        }
      };
    })(this));
  };

  SimpleDrive.prototype.create = function() {
    var fullpath, path, relativepath, _ref;
    path = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    _ref = this.path.apply(this, path), fullpath = _ref[0], relativepath = _ref[1];
    return new Promise(function(yell, cry) {
      return fs.createWriteStream(fullpath).on('open', function() {
        return yell(this);
      }).on('error', cry);
    });
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
  function Entity(drive, stat, paths) {
    this.isDirectory = stat.directory;
    this.drive = drive;
    this.stat = stat;
    this.paths = paths;
    this.relpath = paths.relpath, this.fullpath = paths.fullpath, this.name = paths.name;
  }

  Entity.prototype.info = function() {
    return {
      isDirectory: this.isDirectory,
      name: this.name,
      path: this.relpath,
      stat: this.stat
    };
  };

  Entity.prototype.rename = function(to) {
    var fullpath, relativepath, _ref;
    _ref = this.drive.path(to), fullpath = _ref[0], relativepath = _ref[1];
    return fs.renameAsync(this.fullpath, fullpath).then((function(_this) {
      return function() {
        return _this.drive.stat(to);
      };
    })(this));
  };

  return Entity;

})();

module.exports.Directory = Directory = (function(_super) {
  __extends(Directory, _super);

  function Directory() {
    return Directory.__super__.constructor.apply(this, arguments);
  }

  Directory.prototype.list = function() {
    return fs.readdirAsync(this.fullpath).then((function(_this) {
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
    return (_ref = this.drive).stat.apply(_ref, [this.relpath].concat(__slice.call(path)));
  };

  Directory.prototype.remove = function() {
    return fs.rmdirAsync(this.fullpath);
  };

  return Directory;

})(Entity);

module.exports.File = File = (function(_super) {
  __extends(File, _super);

  function File() {
    return File.__super__.constructor.apply(this, arguments);
  }

  File.prototype.read = function() {
    return fs.createReadStream(this.fullpath);
  };

  File.prototype.remove = function() {
    return fs.unlinkAsync(this.fullpath);
  };

  return File;

})(Entity);
