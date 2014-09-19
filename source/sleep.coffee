###
Rest server part!
###

Sleep = require 'sleeprest'
Promise = require 'bluebird'
URL = require 'url'

# For PUT types
request = require 'request'

# For POST modifiers
AssertEntity = require './lib/assert-entity'
{Transform} = require 'readable-stream'
class LinesReplacer extends Transform
  constructor: (lines) ->
    super
    @lines = lines
    @line = 0
    @state = 0 # (0 = searching, 1 = replacing)

  _transform: (chunk, encoding, cb) ->
    lines = chunk.toString().split("\n")
    for line, i in lines
      if i isnt 0 # First part doesn't indicate a \n
        @push "\n"
        @line++
        @state = 0

      else if @state is 1 # If previous line ended in replacement
        return cb()

      # Line is to be replaced
      if (replaceLines = @lines[@line + 1])?
        @state = 1
        @push replaceLines
      else
        @push line
    cb()


something = (val) ->
  if not val?
    throw new error "HTTP:422 Need something!!!!"
  val


# Modifiers
MODIFIERS =
  zip: require('./modifiers/zip').zip
  unzip: require('./modifiers/zip').unzip


module.exports = (server, fn) ->
  # Plugin to get the entity
  getEntity = (req) ->
    req.drive.stat(req.params.path).then (stat) ->
      req.entity = stat
    .catch (err) ->
      throw new Error "HTTP:404 File not found."

  parseQuery = (req) ->
    # Use the original url for now -> _url
    req.query = URL.parse(req._url, true).query

  # Get the modifiers to apply to the file
  getModifiers = (req) ->
    if not req.query.modifier?
      req.modifiers = []
      return

    req.modifiers = req.query.modifier.split(',').map (mod) ->
      mod.trim()
    .map (name) ->
      mod = MODIFIERS[name]
      if not mod?
        throw new Error 'HTTP:501 Unknown modifier!'
      return mod


  server.res(/(.*)/, 'path').use (req) ->
    # Use the callback fn to get the drive
    Promise.try(fn, [req]).then (result) ->
      req.drive = result

  .use(parseQuery)

  # READ
  .get getEntity, getModifiers, (req) ->
    {entity, modifiers} = req

    # Apply modifiers to the entity, to get a new one
    Promise.reduce(modifiers, (entity, modifier) ->
      assertEntity = new AssertEntity entity
      modifier(entity, assertEntity)

    , entity).then (entity) =>
      @header 'x-type', if entity.isDirectory then 'directory' else 'file'

      if entity.isDirectory
        dir = entity.info()
        return entity.list().then (list) =>
          # Just the files
          dir.files = list.map (file) ->
            file.name

          # Add embedded files
          thisHref = @_links.self.href
          @embed 'files', list.map (file) =>
            info = file.info()
            info._link =
              self: href: thisHref + '/' + file.name
              parent: href: thisHref
            info

          dir

        entity.list().then (list) ->
          type: 'directory'
          files: list
      else
        entity.read()


  # WRITE
  .put Sleep.bodyParser(), (req) ->
    {path} = req.params

    # If it is a 'raw' put, put.
    if not req.body?
      return req.drive.create(path).then (file) ->
        req.pipe file
        statusCode: 201
        path: path
        note: 'File uploaded perfectly fine :-)'
      .catch (err) ->
        throw new Error "HTTP:409 You are trying to put a file on a directory.. good luck XD"

    sources =
      http: (opts, dest) ->
        {url} = opts
        if not url?
          throw new Error "HTTP:422 Need to have URL to download from!"

        new Promise (yell, cry) ->
          response = request(opts.url)
          response.pipe dest
          response.on 'error', (err) ->
            cry err
          response.on 'end', ->
            yell "Successfull download from #{opts.url}!"


    # Action-able put, it should have a 'type' field
    {source} = req.body
    if not source?
      throw new Error "HTTP:422 I don't know what to do, please tell me what source to get this from! (Source: #{Object.keys(sources).join(', ')})"
    if not sources[source]?
      throw new Error "HTTP:501 Can't handle these kind of sources yet, but I can handle #{Object.keys(sources).join(', ')}!"

    destination = req.drive.create(path).catch ->
      throw new Error "HTTP:409 You know '#{path}' is a directory? And you are trying to put a file? Yes??"

    .then (file) ->
      sources[source](req.body, file).catch (err) ->
        throw new Error "HTTP:418 Source gave an error, D-: (#{err.message})"

    .then (note) ->
      statusCode: 201
      path: path
      note: note


  # ALTER
  .post getEntity, Sleep.bodyParser(), (req) ->
    {entity} = req
    {action} = req.body
    action = action.toLowerCase()

    if action is 'rename'
      to = @require req.body, 'to'
      entity.rename(to).then =>
        @status 301
        @header 'Location', to

        location: to

    else if action is 'edit'
      lines = @require req.body, 'lines'
      replacer = new LinesReplacer lines
      entity.modify(replacer).then ->
        lines: lines

    else
      throw new Error "HTTP:501 Don't know what you mean? #{action}?"


  # REMOVE
  .delete getEntity, (req) ->
    {entity} = req
    entity.remove()
