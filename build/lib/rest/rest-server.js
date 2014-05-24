// YellowLeaf FTP by Michiel Dral 
var Promise, ServerPool, colors, merge, path, pipe3, polyfill, restify, settings, socketio, _;

Promise = require('bluebird');

Promise.longStackTraces();

ServerPool = require("./lib/ServerPool");

restify = require('restify');

socketio = require('socket.io');

colors = require('colors');

merge = require('deepmerge');

path = require('path');

_ = require('lodash');

_.str = require('underscore.string');

_.mixin(_.str.exports());

pipe3 = function(func) {
  return function(req, res, next) {
    return Promise["try"](func, [req, res])["catch"](function(err) {
      if (err instanceof restify.InvalidCredentialsError) {
        res.send(err);
        throw err;
      }
      if ((err instanceof restify.InternalError) || (!(err instanceof restify.RestError))) {
        console.log(err.stack);
        err = new restify.InternalError("Something went wrong.. this shouldn't happen!");
      }
      return {
        statusCode: err.statusCode,
        message: err.message
      };
    }).then(function(val) {
      if (val == null) {
        val = {};
      }
      if (typeof val !== "object") {
        val = {
          message: val
        };
      }
      if (val instanceof Array) {
        val = {
          items: val
        };
      }
      if (val._links == null) {
        val._links = {};
      }
      val._links = merge(req._links, val._links);
      if (req._embedded != null) {
        val._embedded = req._embedded;
      }
      if (val.statusCode == null) {
        val.statusCode = val.http || 200;
      }
      if (val.statusCode != null) {
        res.status(val.statusCode);
        delete val.statusCode;
      }
      return res.send(val);
    }).then(function() {
      return next();
    })["catch"](function() {});
  };
};

polyfill = require("polyfill");

module.exports = function(settings) {
  var $group, $id, $version, $view, $viewproper, io, resourceNotFound, server, serverpool, viewFn;
  serverpool = new ServerPool;
  server = restify.createServer({
    name: 'Terraformer API',
    verion: 1
  });

  /*
  Socket IO for console!
   */
  io = socketio.listen(server);
  io.set('log level', 1);
  io.sockets.on('connection', function(socket) {
    socket.emit('send_info');
    return socket.promiseOnce('info').bind({}).then(function(info) {
      var group, key;
      group = info.group, server = info.server, key = info.key, this.last = info.last;
      socket.set('group', group);
      socket.set('server', server);
      return serverpool.getByGroupId(group, server).withKey(key);
    }).then(function(server) {
      var getFrom;
      getFrom = this.last;
      if (getFrom != null) {
        getFrom = new Date(getFrom);
        server.log.get().forEach(function(message) {
          if (getFrom < message.creation) {
            return socket.emit('line', message.message);
          }
        });
      }
      server.on('line', function(line) {
        return socket.emit('line', line);
      });
      socket.on('line', function(line) {
        return server.write(line);
      });
      return server.on('stop', function() {
        socket.emit('err', {
          message: 'Server stopped.',
          shouldhappensometime: true
        });
        return socket.disconnect();
      });
    })["catch"](function(err) {
      console.log(err.stack);
      socket.emit('err', {
        message: "Bad authentication!",
        shouldhappensometime: false
      });
      return socket.disconnect();
    });
  });

  /*
  End of socket IO stuff!
   */
  server.use(restify.CORS());
  server.use(restify.fullResponse());
  server.use(restify.bodyParser({
    mapParams: false
  }));
  server.use(restify.queryParser({
    mapParams: false
  }));
  server.use(restify.gzipResponse());
  server.use(restify.jsonp());
  server.use(function(req, res, next) {
    if (req._links == null) {
      req._links = {};
    }
    if (req.body == null) {
      req.body = {};
    }
    if (req.query == null) {
      req.query = {};
    }
    req.rest = restify;
    return next();
  });
  server.use(restify.authorizationParser());
  server.use(function(req, res, next) {
    req._links.self = {
      href: req.path()
    };
    req.link = function(name, href, more) {
      if (more == null) {
        more = {};
      }
      if (href instanceof Array) {
        return href.forEach(function(h, i) {
          return req.link(name, h, more[i]);
        });
      }
      more.href = req.makelink(href, more);
      if (req._links[name] != null) {
        if (!(req._links[name] instanceof Array)) {
          req._links[name] = [req._links[name]];
        }
        return req._links[name].push(more);
      } else {
        return req._links[name] = more;
      }
    };
    req.makelink = function(href, more) {
      if (more == null) {
        more = {};
      }
      if (href[0] === '/') {
        return href;
      } else {
        return path.join(req.path(), href);
      }
    };
    req.embed = function(name, resource) {
      var e, links;
      if (resource instanceof Array) {
        return resource.forEach(function(res) {
          return req.embed(name, res);
        });
      }
      if (resource.href) {
        links = resource._links || (resource._links = {});
        links.self = {
          href: resource.href
        };
      }
      e = req._embedded || (req._embedded = {});
      if (e[name] != null) {
        if (!(e[name] instanceof Array)) {
          e[name] = [e[name]];
        }
        return e[name].push(resource);
      } else {
        return e[name] = resource;
      }
    };
    return next();
  });
  server.get(/\/browser\/?.*/, restify.serveStatic({
    directory: "" + __dirname + "/hal-browser",
    "default": 'browser.html'
  }));
  $version = "/:version";
  $group = "" + $version + "/:group";
  $id = "" + $group + "/:id";
  $viewproper = "" + $id + "/:view(/more...)";
  $view = /^\/[0-9]+\/([a-zA-Z0-9_\.~-]+)\/([a-zA-Z0-9_\.~-]+)\/([a-zA-Z0-9_\.~-]+)(?:\/)?(.*)?/;
  server.get("/", pipe3(function(req) {
    req.link('v1', '/1');
    return {
      welcome: "Just move to version one.. now please!"
    };
  }));

  /*
  Group listing
   */
  server.get($version, pipe3(function(req) {
    var version;
    version = req.params.version;
    req.link('group', '/{group}', {
      templated: true
    });
    req.embed('group', _.map(serverpool.groups, function(group, name) {
      return {
        name: name,
        href: req.makelink(name),
        _links: {
          self: {
            href: req.makelink(name)
          },
          server: _.map(group, function(server, id) {
            return {
              href: req.makelink("/" + version + "/" + name + "/" + id)
            };
          })
        }
      };
    }));
    return {
      welcome: "Welcome! This is the actual endpoint of the api. Well, version 1."
    };
  }));

  /*
  Server listing
   */
  server.get($group, pipe3(function(req) {
    var group, _ref, _ref1;
    req.link('server', '{server}', {
      templated: true
    });
    if (((_ref = serverpool.groups) != null ? _ref[req.params.group] : void 0) != null) {
      group = (_ref1 = serverpool.groups) != null ? _ref1[req.params.group] : void 0;
      req.embed('server', _.map(group, function(server, id) {
        return server.toRest(req);
      }));
    }
    return {
      welcome: "Here are all the servers in group " + req.params.group + " listed."
    };
  }));

  /*
  Just the server
   */
  server.post($id, pipe3(function(req) {
    "Start a new server of that type";
    var group, id, _ref;
    _ref = req.params, group = _ref.group, id = _ref.id;
    req.link('parent', "../");
    return serverpool.start(group, id, req);
  }));
  server.get($id, pipe3(function(req, res) {

    /*
    res.meta =
      format: $id
      description: "Server resource, use this and all it's views to interact with it."
      methods:
        get: 'Check if the server is running.'
        post:
          description: 'Start the server.',
          required: ['type', 'cwd']
        delete: 'Stop the server'
     */
    "Is this server running?";
    var group;
    group = req.params.group;
    req.link('group', "../");
    return serverpool.get(req).then(function(server) {
      return server.toRest(req);
    });
  }));
  server.del($id, pipe3(function(req) {
    "Stop that server!";
    var group;
    group = req.params.group;
    req.link('parent', "/" + group);
    return serverpool.get(req).then(function(server) {
      server.stop(req.body);
      return {
        statusCode: 202,
        message: "Stopping..."
      };
    });
  }));

  /*
  Apply action on the server
   */
  resourceNotFound = function() {
    throw new restify.ResourceNotFoundError("That action is unknown to me!");
  };
  viewFn = function(method, req) {
    "Get the {view} of the server.";
    req.params = {
      group: req.params[0],
      id: req.params[1],
      view: req.params[2],
      url: req.params[3]
    };
    return serverpool.get(req).then(function(server) {
      var t;
      req.link('parent', "/" + req.params.group + "/" + req.params.id);
      t = server["" + method + "_" + req.params.view] || resourceNotFound;
      return t.call(server, req);
    });
  };
  ['get', 'post', 'put', 'del'].forEach(function(method) {
    return server[method]($view, pipe3(viewFn.bind(void 0, method)));
  });
  process.on('SIGINT', function() {
    console.log("\nGracefully shutting down.. bye!");
    return serverpool.shutdown().then(function() {
      return process.exit();
    });
  });
  return server.listen(3003);
};

if (!module.parent) {
  settings = require("./config");
  module.exports(settings);
}
