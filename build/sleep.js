// YellowLeaf FTP by Michiel Dral 

/*
Rest server part!
 */
var Promise, Sleep, request, something;

Sleep = require('sleeprest');

Promise = require('bluebird');

request = require('request');

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
      this.status(201);
      req.pipe(req.drive.create(path));
      return {
        path: path,
        note: 'File uploaded perfectly fine :-)'
      };
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
    destination = req.drive.create(path);
    return sources[source](req.body, destination).then(function(note) {
      return {
        statusCode: 201,
        path: path,
        note: note
      };
    })["catch"](function(err) {
      throw new Error("HTTP:418 Source gave an error, D-: (" + err.message + ")");
    });
  }).post(getEntity, Sleep.bodyParser(), function(req) {
    var action, entity, to;
    entity = req.entity;
    action = req.body.action;
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
    }
  })["delete"](getEntity, function(req) {
    var entity;
    entity = req.entity;
    return entity.remove();
  });
};
