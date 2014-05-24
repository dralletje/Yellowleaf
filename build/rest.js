// YellowLeaf FTP by Michiel Dral 

/*
Rest server part, too edit the database :)
 */
var Promise, Readable, http, something;

http = require('http');

Promise = require('bluebird');

Readable = require('stream').Readable;

something = function(val) {
  if (val == null) {
    throw new restify.ResourceNotFoundError;
  }
  return val;
};

module.exports = function(opts) {
  var drive, prefix, server;
  prefix = opts.prefix || '';
  drive = opts.drive;
  if (drive == null) {
    throw new Error("Drive is required!");
  }
  server = http.createServer(function(req, res) {
    var method, url;
    url = req.url;
    method = req.method;
    return Promise["try"](function() {
      var path;
      if (!~url.indexOf(prefix)) {
        return;
      }
      url = url.slice(prefix.length);
      if (!~url.indexOf('/v1')) {
        throw new Error('Wrong version! (' + url + ')');
      }
      url = url.slice('/v1'.length);
      path = url;
      return drive.stat(path);
    }).then(function(entity) {
      var methods, moreMethods;
      methods = {
        DELETE: function() {
          res.statusCode = 204;
          return entity.remove();
        }
      };
      if (entity.isDirectory) {
        moreMethods = {
          GET: function() {
            return entity.list().then(function(list) {
              return {
                type: 'directory',
                files: list
              };
            });
          }
        };
      } else {
        moreMethods = {
          GET: function() {
            return 'Hello';
          }
        };
      }
      moreMethods.__proto__ = methods;
      if (moreMethods[method] != null) {
        return moreMethods[method](entity);
      } else {
        res.statusCode = 405;
        throw new Error('Method not allowed');
      }
    }).then(function(body) {
      if (body instanceof Readable) {
        res.setHeader('content-type', 'text/plain');
        return body.pipe(res);
      } else if (typeof body === 'object') {
        res.setHeader('content-type', 'application/json');
        return res.end(JSON.stringify(body));
      } else {
        return res.end(body);
      }
    })["catch"](function(err) {
      res.statusCode = 400;
      res.setHeader('content-type', 'application/json');
      return res.end(JSON.stringify({
        error: err.message
      }));
    });
  });
  return server.listen(opts.port || 3009);
};
