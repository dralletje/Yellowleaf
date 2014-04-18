chai = require 'chai'
should = chai.should()
expect = chai.expect
chai.use require 'chai-as-promised'

debug = require('debug')('[TC]', 'yellow')

# Start the ftp server
main = require '../source/main'

port = Math.round Math.random() * 100000
server = main (user, password) ->
  if user is 'jelle' and password is 'jelle'
    "test/example"
, port

# Get the Client
Client = require './ftpclient'

randomstring = (length=12) ->
  chars = 'abcdefghijklmnopqrstuvwxyz'
  string = ''
  for i in [0..length]
    num = Math.round Math.random() * chars.length
    string += chars[num]
  string

Promise = require 'bluebird'
Promise::log = (message) ->
  @then (thing) ->
    debug message, thing
    thing

# Extract ID from ftp message "220 Welcome! \r\n" -> 220
Promise::ftpid = () ->
  @then (message) ->
    Number message.split(' ')[0]

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

before ->
  @server = new Client(port)


describe 'login', ->
  it 'should connect fine', ->
    @server.then.should.be.fulfilled

  it 'should welcome me', ->
    @server.read().ftpid().should.become 220

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

  it 'should give me a list', ->
    @server.useDataConnection 'LIST', (dataconnection) =>
      dataconnection.suck()
    .then (message) ->
      message.split("\r\n").slice(0,-1).map (line) ->
        line.match /[\-drwx]{10} \d \w+ \w+ \d+ \w+ \d+ \d+:\d+ ([a-zA-Z.\-]+)/
    .should.eventually.not.contain(null)


describe 'File', ->
  it 'should generate a random filename and content', ->
    @name = randomstring() + '.txt'
    @name2 = randomstring() + '.json'
    @content = randomstring 512

  it 'should make a file', ->
    @server.useDataConnection "STOR #{@name}", (dataconnection) =>
      dataconnection.write @content

  it 'should give me the contents of the file', ->
    @server.useDataConnection "RETR #{@name}", (dataconnection) ->
      dataconnection.suck()
    .should.become @content

  it 'should rename the file', ->
    @server.ask("RNFR #{@name}").ftpid().should.become(350).then =>
      @server.ask("RNTO #{@name2}")
    .ftpid().should.become(250)

  it 'should delete the file', ->
    @server.ask("DELE #{@name2}").ftpid().should.become 250

after ->
  debug 'Closing connection..'
  server.close()
