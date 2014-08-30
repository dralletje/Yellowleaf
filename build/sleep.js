// YellowLeaf FTP by Michiel Dral 

/*
Rest server part!
 */
var LinesReplacer, Promise, Sleep, Transform, request, something,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

Sleep = require('sleeprest');

Promise = require('bluebird');

request = require('request');

Transform = require('readable-stream').Transform;

LinesReplacer = (function(_super) {
  __extends(LinesReplacer, _super);

  function LinesReplacer(lines) {
    LinesReplacer.__super__.constructor.apply(this, arguments);
    this.lines = lines;
    this.line = 0;
    this.state = 0;
  }

  LinesReplacer.prototype._transform = function(chunk, encoding, cb) {
    var i, line, lines, replaceLines, _i, _len;
    lines = chunk.toString().split("\n");
    for (i = _i = 0, _len = lines.length; _i < _len; i = ++_i) {
      line = lines[i];
      if (i !== 0) {
        this.push("\n");
        this.line++;
        this.state = 0;
      } else if (this.state === 1) {
        return cb();
      }
      if ((replaceLines = this.lines[this.line + 1]) != null) {
        this.state = 1;
        this.push(replaceLines);
      } else {
        this.push(line);
      }
    }
    return cb();
  };

  return LinesReplacer;

})(Transform);

something = function(val) {
  if (val == null) {
    throw new error("HTTP:422 Need something!!!!");
  }
  return val;
};

module.exports = function(server, fn) {
  var getEntity;
  getEntity = function(req) {
    return req.drive.stat(req.params.path).then(function(stat) {
      return req.entity = stat;
    })["catch"](function(err) {
      throw new Error("HTTP:404 File not found.");
    });
  };
  return server.res(/(.*)/, 'path').use(function(req) {
    return Promise["try"](fn, [req]).then(function(result) {
      return req.drive = result;
    });
  }).get(getEntity, function(req) {
    var dir, entity;
    entity = req.entity;
    this.header('x-type', entity.isDirectory ? 'directory' : 'file');
    if (entity.isDirectory) {
      dir = entity.info();
      return entity.list().then((function(_this) {
        return function(list) {
          var thisHref;
          dir.files = list.map(function(file) {
            return file.name;
          });
          thisHref = _this._links.self.href;
          _this.embed('files', list.map(function(file) {
            var info;
            info = file.info();
            info._link = {
              self: {
                href: thisHref + '/' + file.name
              },
              parent: {
                href: thisHref
              }
            };
            return info;
          }));
          return dir;
        };
      })(this));
      return entity.list().then(function(list) {
        return {
          type: 'directory',
          files: list
        };
      });
    } else {
      return entity.read();
    }
  }).put(Sleep.bodyParser(), function(req) {
    var destination, path, source, sources;
    path = req.params.path;
    if (req.body == null) {
      return req.drive.create(path).then(function(file) {
        req.pipe(file);
        return {
          statusCode: 201,
          path: path,
          note: 'File uploaded perfectly fine :-)'
        };
      })["catch"](function(err) {
        throw new Error("HTTP:409 You are trying to put a file on a directory.. good luck XD");
      });
    }
    sources = {
      http: function(opts, dest) {
        var url;
        url = opts.url;
        if (url == null) {
          throw new Error("HTTP:422 Need to have URL to download from!");
        }
        return new Promise(function(yell, cry) {
          var response;
          response = request(opts.url);
          response.pipe(dest);
          response.on('error', function(err) {
            return cry(err);
          });
          return response.on('end', function() {
            return yell("Successfull download from " + opts.url + "!");
          });
        });
      }
    };
    source = req.body.source;
    if (source == null) {
      throw new Error("HTTP:422 I don't know what to do, please tell me what source to get this from! (Source: " + (Object.keys(sources).join(', ')) + ")");
    }
    if (sources[source] == null) {
      throw new Error("HTTP:501 Can't handle these kind of sources yet, but I can handle " + (Object.keys(sources).join(', ')) + "!");
    }
    return destination = req.drive.create(path)["catch"](function() {
      throw new Error("HTTP:409 You know '" + path + "' is a directory? And you are trying to put a file? Yes??");
    }).then(function(file) {
      return sources[source](req.body, file)["catch"](function(err) {
        throw new Error("HTTP:418 Source gave an error, D-: (" + err.message + ")");
      });
    }).then(function(note) {
      return {
        statusCode: 201,
        path: path,
        note: note
      };
    });
  }).post(getEntity, Sleep.bodyParser(), function(req) {
    var action, entity, lines, replacer, to;
    entity = req.entity;
    action = req.body.action;
    action = action.toLowerCase();
    if (action === 'rename') {
      to = this.require(req.body, 'to');
      return entity.rename(to).then((function(_this) {
        return function() {
          _this.status(301);
          _this.header('Location', to);
          return {
            location: to
          };
        };
      })(this));
    } else if (action === 'edit') {
      lines = this.require(req.body, 'lines');
      replacer = new LinesReplacer(lines);
      return entity.modify(replacer).then(function() {
        return {
          lines: lines
        };
      });
    } else {
      throw new Error("HTTP:501 Don't know what you mean? " + action + "?");
    }
  })["delete"](getEntity, function(req) {
    var entity;
    entity = req.entity;
    return entity.remove();
  });
};
