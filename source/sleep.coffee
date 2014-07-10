###
Rest server part!
###

Sleep = require 'sleeprest'
Promise = require 'bluebird'

# For put types
request = require 'request'

something = (val) ->
  if not val?
    throw new error "HTTP:422 Need something!!!!"
  val


module.exports = (server, fn) ->
  # Plugin to get the entity
  getEntity = (req) ->
    req.drive.stat(req.params.path).then (stat) ->
      req.entity = stat
    .catch (err) ->
      throw new Error "HTTP:404 File not found."

  server.res(/(.*)/, 'path').use (req) ->
    # Use the callback fn to get the drive
    Promise.try(fn, [req]).then (result) ->
      req.drive = result

  # READ
  .get getEntity, (req) ->
    {entity} = req
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
      @status 201
      req.pipe req.drive.create path
      return {
        path: path
        note: 'File uploaded perfectly fine :-)'
      }

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

    destination = req.drive.create path
    sources[source](req.body, destination).then (note) ->
      statusCode: 201
      path: path
      note: note

    .catch (err) ->
      throw new Error "HTTP:418 Source gave an error, D-: (#{err.message})"


  # ALTER
  .post getEntity, Sleep.bodyParser(), (req) ->
    {entity} = req
    {action} = req.body

    if action is 'rename'
      to = @require req.body, 'to'
      entity.rename(to).then =>
        @status 301
        @header 'Location', to

        location: to

  # REMOVE
  .delete getEntity, (req) ->
    {entity} = req
    entity.remove()
