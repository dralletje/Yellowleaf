# Simple FTP client.. to test the FTP server ;)
Promise = require 'bluebird'
net = require 'net'

EventEmitter = require('events').EventEmitter
EventEmitter::waitFor = (event) ->
  new Promise (resolve, reject) =>
    error = (e) ->
      reject e

    @once event, (args...) ->
      resolve args...
      @removeListener 'error', error
    .once 'error', error

class MatchError extends Error

String::exceptionMatch = (regexp) ->
  match = @match regexp
  if not match?
    throw new MatchError "Regexp '#{regexp}' didn't match '#{this.toString().trim()}'."
  match

module.exports = class FtpClient
  constructor: (port, host) ->
    @port = port
    @host = host

    @then = new Promise (resolve, reject) =>
      @_raw = net.connect(port, resolve).on('error', reject)

  write: (message) ->
    @_raw.write message

  read: ->
    ondata = (pre, data) =>
      data = @_raw.read()
      if not data?
        return @_raw.waitFor('readable').then ondata.bind(this, pre)
      data = (pre or '') + data.toString()
      if not data.match(/\d{3} .*/)?
        return @_raw.waitFor('readable').then ondata.bind(this, data)
      data

    new Promise (resolve, reject) =>
      resolve ondata()


  useDataConnection: (question, fn) ->
    if question instanceof Function
      fn = question
      question = null

    if fn not instanceof Function
      throw new Error 'Second or first argument should be a function!'

    server = this
    @ask('PASV').then (message) ->
      match = message.exceptionMatch /227 [a-zA-Z ]+ \((\d+,\d+,\d+,\d+),(\d+),(\d+)\)/

      host = match[1].replace /,/g, '.'
      port = Number(match[2])*256 + Number(match[3])

      (new DataClient(port, host)).then

    .then (dataclient) ->
      @dataclient = dataclient
      if question?
        server.ask question

    .then (result) ->
      if result?
        result.exceptionMatch /150 .*/
      @result = fn @dataclient

    .then ->
      @dataclient.end()
      server.read()

    .then (response) ->
      response.exceptionMatch /226 .*/
      @result


  ask: (question) ->
    @write question + "\r\n"
    @read()


module.exports.DataClient = class DataClient
  constructor: (port, host) ->
    @port = port
    @host = host

    @then = new Promise (resolve, reject) =>
      @_raw = net.connect port, host, =>
        resolve(this)
      .on 'error', reject

    ['end', 'write'].forEach (method) =>
      @[method] = @_raw[method].bind(@_raw)

  suck: ->
    new Promise (resolve, reject) =>
      body = ''
      @_raw.on 'readable', ->
        data = @read()
        if not data?
          return
        body += data.toString()

      .on 'end', ->
        resolve body

      .on 'error', reject
