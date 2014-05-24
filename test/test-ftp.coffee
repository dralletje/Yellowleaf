chai = require 'chai'
should = chai.should()
expect = chai.expect
chai.use require 'chai-as-promised'

#debug = require('debug')('[TC]', 'yellow')
debug = ->


# SETUP
ftp = require '../build/ftp'
Drive = require '../build/filesystem'

ftpport = Math.round Math.random() * 100000
server = ftp (user, password) ->
  if user is 'jelle' and password is 'jelle'
    new Drive process.cwd() + "/test/example/ftp"
, ftpport
server.debug(no)
console.log 'FTP listening on', ftpport



# PREPARATION
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



# THE TESTS
before ->
  @server = new Client(ftpport)

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

describe 'Folder', ->
  it 'should generate a random foldername and subfile', ->
    @folder = randomstring()
    @name = randomstring() + '.json'
    @content = randomstring 512

  it 'should make the directory and file', ->
    @server.ask("MKD #{@folder}").ftpid().should.become(257).then =>
      @server.ask("CWD #{@folder}").ftpid().should.become(250)
    .then =>
      @server.useDataConnection "STOR #{@name}", (dataconnection) =>
        dataconnection.write @content

  it 'should give me the contents of the file', ->
    @server.useDataConnection "RETR #{@name}", (dataconnection) ->
      dataconnection.suck()
    .should.become @content

  it 'should list this directory correctly', ->
    @server.useDataConnection 'LIST', (dataconnection) =>
      dataconnection.suck()
    .then (message) ->
      message.split("\r\n").slice(0,-1).map (line) ->
        line.match /[\-drwx]{10} \d \w+ \w+ \d+ \w+ \d+ \d+:\d+ ([a-zA-Z.\-]+)/
    .should.eventually.not.contain(null)
    .should.eventually.have.length(1)


  it 'should delete the file and directory', ->
    @server.ask("DELE #{@name}").ftpid().should.become(250).then =>
      @server.ask("CWD /").ftpid().should.become(250)
    .then =>
      @server.ask("RMD #{@folder}").ftpid().should.become(250)

after ->
  debug 'Closing connection..'
  server.close()
