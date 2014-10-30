// YellowLeaf FTP by Michiel Dral 
var JoinedDirectory, JoinedDrive, Nope, Path, Promise, fs, mkdirp, os, rimraf, _,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __slice = [].slice;

Path = require('path');

Promise = require('bluebird');

fs = Promise.promisifyAll(require('fs'));

os = require('os');

rimraf = Promise.promisify(require('rimraf'));

mkdirp = Promise.promisify(require('mkdirp'));

_ = require('lodash');

Nope = (function(_super) {
  __extends(Nope, _super);

  function Nope() {
    return Nope.__super__.constructor.apply(this, arguments);
  }

  return Nope;

})(Error);

module.exports = JoinedDrive = (function() {
  function JoinedDrive(drives) {
    this.drives = drives;
    this.cwd = '/';
  }

  JoinedDrive.prototype.path = function() {
    var file, files;
    files = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    if (this.cwd == null) {
      this.cwd = '/';
    }
    file = Path.join.apply(Path, files);
    if (file.indexOf('/') !== 0) {
      file = Path.join(this.cwd, file);
    }
    return Path.join('/', file);
  };

  JoinedDrive.prototype.dir = function(moveTo) {
    if (moveTo.indexOf('/') !== 0) {
      moveTo = Path.join('/', this.cwd, moveTo);
    }
    return this.cwd = moveTo;
  };

  JoinedDrive.prototype.stat = function() {
    var drive, file, path, paths, _ref;
    paths = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    path = this.path.apply(this, path);
    _ref = this.DriveByPath(path), drive = _ref[0], file = _ref[1];
    if (typeof file === 'string') {
      return drive.stat(file);
    }
    return Promise.resolve(new JoinedDirectory(drive, path, file));
  };

  JoinedDrive.prototype.create = function() {
    var drive, file, path, paths, _ref;
    paths = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    path = this.path.apply(this, path);
    _ref = this.DriveByPath(path), drive = _ref[0], file = _ref[1];
    if (typeof extra !== 'string') {
      throw new Error('ReadOnly');
    }
    return drive.create(file);
  };

  JoinedDrive.prototype.createDir = function() {
    var drive, file, path, _ref;
    path = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    path = this.path.apply(this, path);
    _ref = this.DriveByPath(path), drive = _ref[0], file = _ref[1];
    if (typeof extra !== 'string') {
      throw new Error('ReadOnly');
    }
    return drive.createDir(file);
  };

  JoinedDrive.prototype.DriveByPath = function(p) {
    var ParentDrive, a, n, o, _ref;
    p = p.replace(/\[(\w+)\]/g, '.$1');
    p = p.replace('/', '.');
    p = p.replace(/^\./, '');
    a = p.split('.');
    o = this.drives;
    ParentDrive = null;
    while (a.length) {
      n = a.shift();
      if (n === '') {
        continue;
      }
      if (!o.hasOwnProperty(n)) {
        if (ParentDrive != null) {
          return [ParentDrive, "/" + n + "/" + (a.join('/'))];
        } else {
          throw new Error('File does not exist (' + p + '), I\'m sorry');
        }
      }
      o = o[n];
      if (o.stat != null) {
        return [o, a.join('/')];
      }
      if (((_ref = o['/']) != null ? _ref.stat : void 0) != null) {
        ParentDrive = o['/'];
      }
    }
    n = _(o).pairs().filter(function(t, key) {
      return key !== '/';
    }).object().value();
    return [ParentDrive, n];
  };

  return JoinedDrive;

})();

module.exports.JoinedDirectory = JoinedDirectory = (function() {
  function JoinedDirectory(drive, path, files) {
    this.drive = drive;
    this.stat = {};
    this.files = files;
    this.size = 1;
    this.relpath = this.name = path;
  }

  JoinedDirectory.prototype.isDirectory = true;

  JoinedDirectory.prototype.info = function() {
    return {
      isDirectory: this.isDirectory,
      name: this.name,
      path: this.relpath
    };
  };

  JoinedDirectory.prototype.rename = function(to) {
    throw new Nope;
  };

  JoinedDirectory.prototype.remove = function() {
    throw new Nope;
  };

  JoinedDirectory.prototype.list = function() {
    if (this.drive != null) {
      return this.drive.stat('/').then(function(ent) {
        return ent.list();
      }).then((function(_this) {
        return function(list) {
          console.log(list);
          return list;
        };
      })(this));
    } else {
      console.log('Hi:', this.files);
      return Promise.map(_.pairs(this.files), function(t) {
        var drive, folder;
        folder = t[0], drive = t[1];
        drive = drive.stat('/');
        return [folder, drive];
      }).then(function(list) {
        list = _.object(list);
        return console.log(list);
      });
    }
  };

  JoinedDirectory.prototype.listDeep = function() {
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

  JoinedDirectory.prototype.entity = function() {
    var path, _ref;
    path = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return (_ref = this.drive).stat.apply(_ref, [this.relpath].concat(__slice.call(path)));
  };

  return JoinedDirectory;

})();
