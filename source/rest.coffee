###
Rest server part, too edit the database :)
###

http = require 'http'
Promise = require 'bluebird'
Readable = require('stream').Readable

something = (val) ->
  if not val?
    throw new restify.ResourceNotFoundError
  val


module.exports = (opts) ->
  prefix = opts.prefix || ''
  drive = opts.drive
  if not drive?
    throw new Error "Drive is required!"

  server = http.createServer (req, res) ->
    url = req.url
    method = req.method

    Promise.try ->
      # If attached to another server.. I think?
      if not ~url.indexOf(prefix)
        return
      url = url.slice prefix.length

      # Version:
      if not ~url.indexOf('/v1')
        throw new Error 'Wrong version! ('+url+')'
      url = url.slice '/v1'.length

      path = url
      drive.stat(path)

    .then (entity) ->
      if method is 'PUT'
        res.statusCode = 201
        return path: url

      methods =
        DELETE: ->
          res.statusCode = 204
          entity.remove()

      if entity.isDirectory
        moreMethods =
          GET: ->
            entity.list().then (list) ->
              type: 'directory'
              files: list
      else
        moreMethods =
          GET: ->
            'Hello'

      moreMethods.__proto__ = methods
      if moreMethods[method]?
        return moreMethods[method](entity)
      else
        res.statusCode = 405
        throw new Error 'Method not allowed'

    .then (body) ->
      if body instanceof Readable
        res.setHeader 'content-type', 'text/plain'
        body.pipe(res)
      else if typeof body is 'object'
        res.setHeader 'content-type', 'application/json'
        res.end JSON.stringify body
      else
        res.end(body)

    .catch (err) ->
      res.statusCode = 400
      res.setHeader 'content-type', 'application/json'
      res.end JSON.stringify
        error: err.message
        #stack: err.stack


  server.listen opts.port || 3009
