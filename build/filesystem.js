// YellowLeaf FTP by Michiel Dral 
var Directory, Entity, File, Path, Promise, SimpleDrive, debug, fs, mkdirp, os, rimraf, _,
  __slice = [].slice,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

Path = require('path');

Promise = require('bluebird');

fs = Promise.promisifyAll(require('fs'));

os = require('os');

rimraf = Promise.promisify(require('rimraf'));

mkdirp = Promise.promisify(require('mkdirp'));

_ = require('lodash');

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
    file = Path.join.apply(Path, files);
    if (file.indexOf('/') !== 0) {
      file = Path.join(this.cwd, file);
    }
    file = Path.join('/', file);
    return [Path.join(this.directory, file), file];
  };

  SimpleDrive.prototype.dir = function(moveTo) {
    if (moveTo.indexOf('/') !== 0) {
      moveTo = Path.join('/', this.cwd, moveTo);
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
    return mkdirp(Path.dirname(fullpath), {}).then(function() {
      return new Promise(function(yell, cry) {
        return fs.createWriteStream(fullpath).on('open', function() {
          return yell(this);
        }).on('error', cry);
      });
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
    this.size = stat.size;
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

  Entity.prototype.remove = function() {
    return rimraf(this.fullpath);
  };

  return Entity;

})();

module.exports.Directory = Directory = (function(_super) {
  __extends(Directory, _super);

  function Directory() {
    return Directory.__super__.constructor.apply(this, arguments);
  }

  Directory.prototype.list = function() {
    return fs.readdirAsync(this.fullpath).map((function(_this) {
      return function(entity) {
        return _this.entity(entity);
      };
    })(this));
  };

  Directory.prototype.listDeep = function() {
    return this.list().map(function(entity) {
      var list;
      if (!entity.isDirectory) {
        return entity;
      }
      list = entity.listDeep();
      list.push(entity);
      return list;
    }).then(_.flatten).map((function(_this) {
      return function(entity) {
        entity.relpath = entity.relpath.slice(_this.relpath.length);
        return entity;
      };
    })(this));
  };

  Directory.prototype.entity = function() {
    var path, _ref;
    path = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return (_ref = this.drive).stat.apply(_ref, [this.relpath].concat(__slice.call(path)));
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

  File.prototype.write = function() {
    return fs.createWriteStream(this.fullpath);
  };

  File.prototype.modify = function(fnOrStream) {
    var now, path;
    now = new Date;
    path = [os.tmpdir(), now.getYear(), now.getMonth(), now.getDate(), '-', process.pid, '-', (Math.random() * 0x100000000 + 1).toString(36)].join('');
    return new Promise((function(_this) {
      return function(yell, cry) {
        return _this.read().pipe(fnOrStream).pipe(fs.createWriteStream(path)).on('finish', yell);
      };
    })(this)).bind(this).then(function() {
      return this.remove();
    }).then(function() {
      return fs.renameAsync(path, this.fullpath);
    });
  };

  return File;

})(Entity);
