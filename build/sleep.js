// YellowLeaf FTP by Michiel Dral 

/*
Rest server part!
 */
var Promise, Sleep, something;

Sleep = require('sleeprest');

Promise = require('bluebird');

something = function(val) {
  if (val == null) {
    throw new error("404, need something!!!!");
  }
  return val;
};

module.exports = function(server, fn) {
  var getEntity;
  getEntity = function(req) {
    return req.drive.stat(req.params.path).then(function(stat) {
      return req.entity = stat;
    });
  };
  return server.res(/(.*)/, 'path').use(function(req) {
    return req.drive = fn(req);
  }).get(getEntity, function(req) {
    var entity;
    entity = req.entity;
    this.header('x-type', entity.isDirectory ? 'directory' : 'file');
    if (entity.isDirectory) {
      return entity.list().then(function(list) {
        return {
          type: 'directory',
          files: list
        };
      });
    } else {
      return entity.read();
    }
  }).put(function(req) {
    var path;
    path = req.params.path;
    this.status(201);
    req.pipe(req.drive.create(path));
    return {
      path: path
    };
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
