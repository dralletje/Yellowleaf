gulp = require("gulp")
plumber = require("gulp-plumber")

coffee = require("gulp-coffee")
header = require("gulp-header")
mocha = require('gulp-spawn-mocha')

paths =
  coffee: './source/**/*.coffee'
  test: './test/test-*.coffee'
  anytest: './test/*.coffee'

gulp.task "coffee", (cb) ->
  gulp.src(paths.coffee)
    .pipe(plumber())
    .pipe(coffee(bare: true))
    .pipe(header("// YellowLeaf FTP by Michiel Dral \n"))
    .pipe(gulp.dest('./build/'))
    .on "end", ->
      console.log "Done compiling Coffeescript!"

gulp.task 'test', ['coffee'], ->
  gulp.src(paths.test, read: false)
    #.pipe(plumber())
    .pipe(mocha())
    .on('error', console.log)
    .on 'end', ->
      console.log "Tests ran!"


# Rerun the task when a file changes
gulp.task "watch", ->
  gulp.watch paths.coffee, ["coffee"]
  gulp.watch [paths.coffee, paths.anytest], ["test"]

gulp.task "default", [
  "test"
  "coffee"
]
