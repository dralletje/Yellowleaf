chai = require 'chai'
should = chai.should()
expect = chai.expect
chai.use require 'chai-as-promised'

debug = require('debug')('test:rest')


# SETUP
Sleep = require 'sleeprest'
yellowleaf = require '../build/sleep'
Drive = require '../build/filesystem'

port = Math.round Math.random() * 65536
server = new Sleep
drive = new Drive process.cwd() + "/test/example/rest"
yellowleaf server, ->
  drive
server.listen port

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

log = (response) ->
  console.log response
  response

console.log """
  The one and only
  YELLOWLEAF SLEEP
  Test suite!!!
"""

# THE TESTS
before ->
  @client = new Client('http://localhost:'+port)

describe 'REST:', ->
  describe 'Root', ->
    it 'should list root', ->
      @client.get('/').then(statuscode 200).then (result) ->
        result.body.should.have.property 'isDirectory', true
        result.headers.should.have.property 'x-type', 'directory'
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
      @client.get("/#{@name}").then(statuscode 200).then (res) ->
        res.body = res.body.toString()
        res
      .should.eventually.have.property('body', @content)

    it 'should rename the file', ->
      @client.post("/#{@name}", 'Content-Type': 'application/json').send(
        action: 'rename'
        to: '/' + @name2
      ).then(statuscode 301).then (result) =>
        result.headers.should.have.property 'location'
        result.body.should.have.property 'location', '/' + @name2

    it 'should delete the file', ->
      @client.delete("/#{@name2}").then(statuscode 200)

  describe 'HTTP PUT', ->
    before ->
      http = require 'http'
      debug 'HTTP PUT start (starting server)'

      # Create a server that 'just sends a string'.
      @response = randomstring 512
      @port = Math.round Math.random() * 100000
      http.createServer (req, res) =>
        res.end @response
      .listen @port

    it 'should download file', ->
      @path = '/' + randomstring() + '.txt'
      @client.put(@path, 'Content-Type': 'application/json').send(
        source: 'http'
        url: "http://localhost:#{@port}/"
      ).then(statuscode 201)

    it 'should validate the file', ->
      @client.get(@path).then(statuscode 200)
        .get('body').call('toString').should.become(@response)

    it 'should delete the file', ->
      @client.delete(@path).then(statuscode 200)

  describe 'Recursive removal', ->
    it 'should make file inside folder', ->
      @folder = randomstring()
      @file = randomstring() + '.txt'
      @content = randomstring 512

      @client.put("/#{@folder}/#{@file}").send(@content).then(statuscode 201)
      .should.eventually.have.property('body')
      .with.property('path', "/#{@folder}/#{@file}")

    it 'should remove this folder with his file', ->
      @client.delete("/#{@folder}").then(statuscode 200)


  describe 'File modification', ->
    it 'should make a file', ->
      @file = '/' + randomstring() + '.txt'
      @l = 2
      @lines = [
        randomstring(@l)
        randomstring(@l)
        randomstring(@l)
        randomstring(@l)
        randomstring(@l)
      ]
      @client.put(@file).send(@lines.join "\n").then(statuscode 201)

    it 'should validate the contents', ->
      @client.get(@file).then(statuscode 200).then (res) ->
        res.body.toString()
      .should.become(@lines.join "\n")

    it 'should change the lines 2 and 5', ->
      @lines[1] = randomstring(@l)
      @lines[4] = randomstring(@l)

      @client.post(@file, 'Content-Type': 'application/json').send
        action: 'edit'
        lines:
          2: @lines[1]
          5: @lines[4]
      .then(statuscode 200)

    it 'should have the lines changed', ->
      @client.get(@file).then(statuscode 200)
        .get('body').call('toString').should.become(@lines.join "\n")

    it 'should clean up the file', ->
      @client.delete(@file).then(statuscode 200)

  unzip = require 'unzip'
  describe 'Zip', ->
    it 'should create two files in a folder', ->
      @folder = '/' + randomstring()

      @name = @folder + '/' + randomstring() + '.txt'
      @content = randomstring 512

      @name2 = @folder + '/' + randomstring() + '.txt'
      @content2 = randomstring 512

      @client.put(@name).send(@content)
      .then(statuscode 201).then =>
        @client.put(@name2).send(@content2)
      .then(statuscode 201)

    # it 'should generate a zip of the directory', ->
    #   @client.get(@folder + '?modifier=zip').getResponse()
    #   .then(statuscode 200)
    #   .then (res) ->
    #     res.pipe(unzip.Parse())
    #     .on 'entry', (entry) ->
    #       fileName = entry.path
    #       type = entry.type # 'Directory' or 'File'
    #       size = entry.size
    #
    #       console.log fileName, type, size
    #
    #       if fileName is "this IS the file I'm looking for"
    #         entry.autodrain()
    #       else
    #         entry.autodrain()

      #.then (res) ->
      #  fs = require 'fs'
      #  res.pipe fs.createWriteStream './test.zip'

    it 'should clean up the directory', ->
      @client.delete(@folder).then(statuscode 200).then =>
        @client.get(@folder)
      .then(statuscode 404)

    # fs.createReadStream('path/to/archive.zip').pipe(unzip.Extract({ path: 'output/path' }));


  describe 'Errors', ->
    it 'should not write a file to a directory', ->
      @client.put('/').send(randomstring 512)
        .then(statuscode 409)

    it 'should not write from a http source to a directory', ->
      @client.put('/', 'Content-Type': 'application/json').send(
        source: 'http'
        url: "http://example.com"
      ).then(statuscode 409)
after ->
  debug 'Closing connection..'
  server.close?()
