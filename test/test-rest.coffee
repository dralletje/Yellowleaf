chai = require 'chai'
should = chai.should()
expect = chai.expect
chai.use require 'chai-as-promised'

#debug = require('debug')('[TC]', 'yellow')
debug = ->


# SETUP
rest = require '../build/rest'
Drive = require '../build/filesystem'

port = Math.round Math.random() * 100000
server = rest
  port: port
  drive: new Drive process.cwd() + "/test/example/rest"

# PREPARATION
Client = require './restclient'

randomstring = (length=12) ->
  chars = 'abcdefghijklmnopqrstuvwxyz'
  string = ''
  for i in [0..length]
    num = Math.round Math.random() * chars.length
    string += chars[num]
  string

Promise = require 'bluebird'
statuscode = (code) ->
  (response) ->
    Promise.try ->
      response.statusCode.should.be.equal code
    .then ->
      response


# THE TESTS
before ->
  @client = new Client 'http://localhost:'+port+'/v1/'

describe 'Root', ->
  it 'should list root', ->
    @client.get('/').then(statuscode 200).then (result) ->
      result.body.type.should.be.eq 'directory'
      result.body.files.should.be.instanceof Array

describe 'File', ->
  it 'should generate a random filename and content', ->
    @name = randomstring() + '.txt'
    @name2 = randomstring() + '.json'
    @content = randomstring 512

  it 'should make a file', ->
    @client.put("/#{@name}").send(@content).then(statuscode 201)
    .should.eventually.have.property('body')
    .with.property('path', "/#{@name}")

  it 'should give me the contents of the file', ->
    @client.get("/#{@name}").then(statuscode 200)
    .should.eventually.have.property('body', @content)

  it 'should rename the file', ->
    @client.post("/#{@name}").send(JSON.stringify
      action: 'rename'
      to: '/' + @name2
    ).then(statuscode, 301)
    .should.eventually.have.property 'location', '/' + @name2

  it 'should delete the file', ->
    @client.delete("/#{@name2}").then(statuscode 204)
    should.have.property 'body', 204

after ->
  debug 'Closing connection..'
  server.close()
