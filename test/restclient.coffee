http = require 'http'
urlparse = require('url').parse
path = require 'path'

Promise = require 'bluebird'

module.exports = class RestClient
  constructor: (base) ->
    @base = urlparse base

  request: (method, url) ->
    uri = Object.create @base
    uri.path = path.join uri.pathname, url

    uri.method = method

    new Request uri

  ['get', 'post', 'put', 'delete'].forEach (method) =>
    @::[method] = (args...) ->
      @request method, args...

module.exports.Request = class Request
  constructor: (uri) ->
    @request = http.request uri
    @hasSend = no

    @getResponse = =>
      @hasSend = yes
      new Promise (resolve, reject) =>
        @request.end()
        @request.once 'response', (res) ->
          resolve res
        .once 'error', (err) ->
          reject err

  then: (args...) ->
    promise = @getResponse().then (res) =>
      new Promise (resolve, reject) =>
        buffers = []
        res.on 'readable', ->
          if (data = @read())?
            buffers.push data
        .on 'end', ->
          resolve
            body: Buffer.concat buffers
            statusCode: res.statusCode
            headers: res.headers
        @request.once 'error', (err) ->
          reject err

    .then (response) ->
      type = response.headers['content-type']
      if type?.match(/^text\/.*$/)?
        response.body = response.body.toString()
      if type is 'application/json'
        response.body = JSON.parse response.body
      response

    if args[0] instanceof Function
      promise.then args...
    else
      promise

  write: (data) ->
    if @hasSend
      throw new Error 'Already ended!'
    @request.write data

  send: (data) ->
    @write data
    this

if not module.parent?
  client = new module.exports 'http://dral.eu'
  client.get('/terraformer/').then (response) ->
    console.log response
