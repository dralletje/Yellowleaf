# SETUP
ftp = require './ftp'
Drive = require './filesystem'

server = ftp (user, password) ->
  if user is 'jelle' and password is 'jelle'
    new Drive process.cwd() + "/test/example/ftp"

.listen(8021)
