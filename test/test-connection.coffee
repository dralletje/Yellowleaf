return

chai = require 'chai'
should = chai.should()
expect = chai.expect
chai.use require 'chai-as-promised'

debug = require('debug')('[Test]', 'yellow')

# Start the ftp server
main = require '../source/main'

port = Math.round Math.random() * 100000
server = main (user, password) ->
  if user is 'jelle' and password is 'jelle'
    "test/example"
, port

net = require 'net'
Promise = require 'bluebird'

Promise::log = (message) ->
  @then (thing) ->
    debug message, thing
    thing

# Extract ID from ftp message "220 Welcome! \r\n" -> 220
Promise::ftpid = () ->
  @then (message) ->
    Number message.split(' ')[0]

EventEmitter = require('events').EventEmitter
EventEmitter::waitFor = (event) ->
  new Promise (resolve, reject) =>
    error = (e) ->
      reject e

    @once event, (args...) ->
      resolve args...
      @removeListener 'error', error
    .once 'error', error

# Stream stuff
Stream = require('stream')
Stream.Readable::chunk = ->
  new Promise (resolve, reject) =>
    data = @read()
    if data?
      return resolve data.toString()

    @waitFor('readable').then () =>
      data = @read()
      if not data?
        @chunk()
      else
        data.toString()
    .then resolve

# For now the same as chunk; Needs to get all contents till end later.
Stream.Readable::suck = Stream.Readable::chunk

Stream.Readable::ftpchunk = ->
  ondata = (pre, data) =>
    data = @read()
    if not data?
      return @waitFor('readable').then ondata.bind(this, pre)
    data = (pre or '') + data.toString()
    if not data.match(/\d{3} .*/)?
      return @waitFor('readable').then ondata.bind(this, data)
    data

  new Promise (resolve, reject) =>
    resolve ondata()

Stream.Duplex::ask = (question) ->
  @write question + "\r\n"
  @ftpchunk()

Stream.Readable::askdata = (question) ->
  @ask('PASV').then (message) ->
    match = message.match /227 [a-zA-Z ]+ \((\d+,\d+,\d+,\d+),(\d+),(\d+)\)/
    if not match?
      throw new Error "Couldn't parse PASV response!"

    host = match[1].replace /,/g, '.'
    port = Number(match[2])*256 + Number(match[3])

    new Promise (resolve, reject) =>
      @dataserver = net.connect(port, host, resolve)
      .on('error', reject)

  .then =>
    @ask(question).ftpid()
  .then (id) ->
    if id isnt 150
      throw new Error "Didn't return a good ID for initializing dataconnection transfer."
  .then ->
    @dataserver.suck()
  .then (content) ->
    @content = content
  .then =>
    @ftpchunk().ftpid()
  .then (id) ->
    if id isnt 226
      throw new Error "Dataconnection not closed properly!"
    @content

before (cb) ->
  @server = net.connect port, ->
    cb()
  .on 'error', (e) ->
    cb(e)

describe 'login', ->
  it 'should connect fine', ->
    @server.ftpchunk().ftpid().should.become 220

  it 'should accept user', ->
    @server.ask('USER jelle').ftpid().should.become 331

  it 'should accept password', ->
    @server.ask('PASS jelle').ftpid().should.become 230

  it 'should reply to SYST', ->
    @server.ask('SYST').should.become "215 UNIX Type: L8\r\n"

  it 'should not crash from FEAT', ->
    @server.ask('FEAT').ftpid().should.become 500

describe 'Directory', ->
  it 'should give me the PWD', ->
    @server.ask('PWD').ftpid().should.become 257

  it 'should reply happy to TYPE I', ->
    @server.ask('TYPE I').ftpid().should.become 200

  it 'should reply to PASV', ->
    @server.ask('PASV').then (message) =>
      match = message.match /227 [a-zA-Z ]+ \((\d+,\d+,\d+,\d+),(\d+),(\d+)\)/
      expect(match).to.exist

      @host = match[1].replace /,/g, '.'
      debug @host
      @port = Number(match[2])*256 + Number(match[3])

      message
    .ftpid().should.become 227

  it 'should have it\'s port open! :-D', (cb) ->
    @dataserver = net.connect @port, @host, =>
      delete @port
      delete @host
      cb()
    .on 'error', (e) ->
      cb(e)

  it 'should inform me about the state of the transfer!', ->
    @server.ask("LIST").ftpid().should.become 150

  it 'should send a list!', ->
    @dataserver.chunk().then (message) ->
      debug 'Got dataserver response'
      message.split("\r\n").slice(0,-1).map (line) ->
        line.match /[\-drwx]{10} \d \w+ \w+ \d+ \w+ \d+ \d+:\d+ ([a-zA-Z.\-]+)/
      .should.not.contain null

  it 'should tell me the list is fully tranfered!', ->
    @server.ftpchunk().ftpid().should.become 226

describe 'File', ->
  it 'should give me the contents of the file', ->
    @server.askdata('RETR text.txt').should.become "Example text"


after ->
  debug 'Closing connection..'
  server.close()
