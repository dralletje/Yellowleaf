###
Rest server part!
###

Sleep = require 'sleeprest'
Promise = require 'bluebird'

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
  .put (req) ->
    {path} = req.params

    @status 201
    req.pipe req.drive.create path
    path: path


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
