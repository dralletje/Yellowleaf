###
Rest server part!
###

Sleep = require 'sleeprest'
Promise = require 'bluebird'

something = (val) ->
  if not val?
    throw new error "404, need something!!!!"
  val


module.exports = (server) ->
  {drive} = opts
  if not drive?
    throw new Error "Drive is required!"

  # Plugin to get the entity
  getEntity = (req) ->
    drive.stat(req.params.path).then (stat) ->
      req.entity = stat

  server = new Sleep

  server.res(/(.*)/, 'path').use (req) ->
    #console.log 'Params:', req.params
    "Nothing"

  # READ
  .get getEntity, (req) ->
    {entity} = req
    @header 'x-type', if entity.isDirectory then 'directory' else 'file'

    if entity.isDirectory
      entity.list().then (list) ->
        type: 'directory'
        files: list
    else
      entity.read()


  # WRITE
  .put (req) ->
    {path} = req.params

    @status 201
    req.pipe drive.create path
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
