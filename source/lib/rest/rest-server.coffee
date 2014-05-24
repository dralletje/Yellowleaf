Promise = require 'bluebird'
Promise.longStackTraces()

ServerPool = require "./lib/ServerPool"

restify = require 'restify'
socketio = require 'socket.io'
colors = require 'colors'
merge = require 'deepmerge'
path = require 'path'

_ = require('lodash')
_.str = require('underscore.string')
_.mixin(_.str.exports())

pipe3 = (func) ->
  (req, res, next) ->
    Promise.try(func, [req, res]).catch (err) ->
      if err instanceof restify.InvalidCredentialsError
        res.send err
        throw err

      if (err instanceof restify.InternalError) or (err not instanceof restify.RestError)
        console.log err.stack
        err = new restify.InternalError "Something went wrong.. this shouldn't happen!"

      # Transform errors into hall-able resources
      statusCode: err.statusCode
      message: err.message

    .then (val) ->
      val ?= {}
      if typeof val isnt "object"
        val = message: val
      if val instanceof Array
        val = items: val

      #val._meta = res.meta or {}
      #val._meta.format = "/#{val._meta.format}/"
      val._links ?= {}
      val._links = merge req._links, val._links

      if req._embedded?
        val._embedded = req._embedded

      val.statusCode ?= val.http or 200
      if val.statusCode?
        res.status val.statusCode
        delete val.statusCode

      res.send val
    .then () ->
      next()
    .catch () ->
      return

# My own polyfill module
polyfill = require "polyfill"

module.exports = (settings) ->
  serverpool = new ServerPool

  # Start the Daemon and wait for requests
  server = restify.createServer
    name: 'Terraformer API'
    verion: 1

  ###
  Socket IO for console!
  ###
  io = socketio.listen server
  io.set 'log level', 1
  io.sockets.on 'connection', (socket) ->
    socket.emit('send_info')
    socket.promiseOnce('info').bind({}).then (info) ->
      {group, server, key, @last} = info
      socket.set 'group', group
      socket.set 'server', server
      serverpool.getByGroupId(group, server).withKey key
    .then (server) ->
      getFrom = @last
      if getFrom?
        getFrom = new Date getFrom
        server.log.get().forEach (message) ->
          if getFrom < message.creation
            socket.emit 'line', message.message

      server.on 'line', (line) ->
        socket.emit 'line', line

      socket.on 'line', (line) ->
        server.write line

      server.on 'stop', () ->
        socket.emit 'err',
          message: 'Server stopped.'
          shouldhappensometime: yes
        socket.disconnect()

    .catch (err) ->
      console.log err.stack
      socket.emit 'err',
        message: "Bad authentication!"
        shouldhappensometime: no
      socket.disconnect()
  ###
  End of socket IO stuff!
  ###

  server.use restify.CORS()
  server.use restify.fullResponse()

  server.use restify.bodyParser(mapParams: false)
  server.use restify.queryParser(mapParams: false)
  server.use restify.gzipResponse()
  server.use restify.jsonp()
  server.use (req, res, next) -> # Fill the request with dummy values when they do not exist yet

    req._links ?= {}
    req.body ?= {}
    req.query ?= {}

    ## Add restify to the req
    req.rest = restify
    next()

  server.use restify.authorizationParser()

  server.use (req, res, next) -> # .link and .embed to link and.. embed!
    ## Add self, but remove the version tag!
    req._links.self = href: req.path()
    req.link = (name, href, more={}) ->
      if href instanceof Array
        return href.forEach (h, i) -> req.link name, h, more[i]
      more.href = req.makelink href, more
      if req._links[name]?
        if req._links[name] not instanceof Array
          req._links[name] = [req._links[name]]
        req._links[name].push more
      else
        req._links[name] = more

    req.makelink = (href, more={}) ->
      if href[0] is '/' then href else path.join req.path(), href

    req.embed = (name, resource) ->
      if resource instanceof Array
        return resource.forEach (res) ->
          req.embed name, res

      ## Add links to the embed!
      if resource.href
        links = resource._links ||= {}
        links.self = href: resource.href
      e = req._embedded ||= {}
      if e[name]?
        if e[name] not instanceof Array
          e[name] = [e[name]]
        e[name].push resource
      else
        e[name] = resource

    next()

  ## HAL browser
  server.get /\/browser\/?.*/, restify.serveStatic
    directory: "#{__dirname}/hal-browser"
    default: 'browser.html'

  $version = "/:version"
  $group = "#{$version}/:group"
  $id = "#{$group}/:id"
  $viewproper = "#{$id}/:view(/more...)"
  $view = /^\/[0-9]+\/([a-zA-Z0-9_\.~-]+)\/([a-zA-Z0-9_\.~-]+)\/([a-zA-Z0-9_\.~-]+)(?:\/)?(.*)?/

  server.get "/", pipe3 (req) ->
    req.link 'v1', '/1'
    welcome: "Just move to version one.. now please!"

  ###
  Group listing
  ###
  server.get $version, pipe3 (req) ->
    {version} = req.params
    req.link 'group', '/{group}', templated: true
    req.embed 'group', _.map serverpool.groups, (group, name) ->
      name: name
      href: req.makelink name
      _links:
        self: href: req.makelink name
        server: _.map group, (server, id) ->
          href: req.makelink "/#{version}/#{name}/#{id}"
    welcome: "Welcome! This is the actual endpoint of the api. Well, version 1."

  ###
  Server listing
  ###
  server.get $group, pipe3 (req) ->
    req.link 'server', '{server}', templated: true
    if serverpool.groups?[req.params.group]?
      group = serverpool.groups?[req.params.group]
      req.embed 'server', _.map group, (server, id) ->
        server.toRest req
    welcome: "Here are all the servers in group #{req.params.group} listed."


  ###
  Just the server
  ###
  server.post $id, pipe3 (req) ->
    "Start a new server of that type"
    {group, id} = req.params
    req.link 'parent', "../"
    serverpool.start(group, id, req)


  server.get $id, pipe3 (req, res) ->
    ###
    res.meta =
      format: $id
      description: "Server resource, use this and all it's views to interact with it."
      methods:
        get: 'Check if the server is running.'
        post:
          description: 'Start the server.',
          required: ['type', 'cwd']
        delete: 'Stop the server'
    ###
    "Is this server running?"
    {group} = req.params
    req.link 'group', "../"
    serverpool.get(req).then (server) ->
      server.toRest(req)

  server.del $id, pipe3 (req) ->
    "Stop that server!"
    {group} = req.params
    req.link 'parent', "/#{group}"
    serverpool.get(req).then (server) ->
      server.stop(req.body)
      statusCode: 202
      message: "Stopping..."

  ###
  Apply action on the server
  ###
  resourceNotFound = () ->
    throw new restify.ResourceNotFoundError "That action is unknown to me!"

  viewFn = (method, req) ->
    "Get the {view} of the server."
    req.params =
      group: req.params[0]
      id: req.params[1]
      view: req.params[2]
      url: req.params[3]

    serverpool.get(req).then (server) ->
      req.link 'parent', "/#{req.params.group}/#{req.params.id}"
      t = server["#{method}_#{req.params.view}"] or resourceNotFound
      t.call server, req

  ['get', 'post', 'put', 'del'].forEach (method) ->
    server[method] $view, pipe3 viewFn.bind undefined, method


  process.on 'SIGINT', () ->
    console.log "\nGracefully shutting down.. bye!"
    serverpool.shutdown().then () ->
      process.exit()
  server.listen 3003


# If not included, run yourself
if not module.parent
    # Get the settings
    settings = require "./config"
    module.exports settings
