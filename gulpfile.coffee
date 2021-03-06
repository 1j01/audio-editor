mkdirp = require 'mkdirp'
watchify = require 'watchify'
browserify = require 'browserify'
coffeeify = require 'coffeeify'
gulp = require 'gulp'
source = require 'vinyl-source-stream'
buffer = require 'vinyl-buffer'
gutil = require 'gulp-util'
sourcemaps = require 'gulp-sourcemaps'

browserify_options =
	entries: ['./src/app.coffee']
	extensions: ['.coffee']
	debug: no

opts = Object.assign {}, watchify.args, browserify_options
b = watchify browserify opts 

b.transform coffeeify

bundle = ->
	b.bundle()
		# log errors if they happen
		.on 'error', gutil.log.bind(gutil, 'Browserify Error')
		.pipe source('bundle.js')
		# "optional, remove if you don't need to buffer file contents"
		.pipe buffer()
		# .pipe sourcemaps.init(loadMaps: true) # loads map from browserify file
		# .pipe sourcemaps.write('./') # writes .map file
		.pipe gulp.dest('./build')

gulp.task 'watch-scripts', bundle
b.on 'update', bundle # on any dep update, runs the bundler
b.on 'log', gutil.log # output build logs

gulp.task 'watch-styles', ->
	gulp.watch ['styles/**/*', 'themes.json'], gulp.series('styles')

enable_postcss_debug = false

gulp.task 'styles', (callback)->
	
	fs = require "fs"
	async = require "async"
	postcss = require "postcss"
	# sugarss = require "sugarss"

	if enable_postcss_debug
		{createDebugger, matcher} = require "postcss-debug"
		
		debug = createDebugger([
			matcher.regex(/amber/)
		])
	
	# TODO: preprocess non-theme-specific css
	
	build_theme = (theme_path, callback)->
		input_file_path = "styles/themes/#{theme_path}"
		output_file_path = "build/themes/#{theme_path}"
		output_dir_path = require("path").dirname(output_file_path)
		mkdirp(output_dir_path).then ->
			fs.readFile input_file_path, "utf8", (err, css)->
				return callback(err) if err
				
				postcss_arg = [
					require("postcss-import")
					# require("postcss-easy-import")
					require("postcss-advanced-variables")
					require("postcss-color-function")
					require("postcss-extend")
					require("postcss-url")(url: "rebase")
				]
				if enable_postcss_debug
					postcss_arg = debug(postcss_arg)
				
				postcss(postcss_arg)
				.process(css, from: input_file_path, to: output_file_path) #, parser: sugarss
				.then (result)->
					fs.writeFile output_file_path, result.css, "utf8", (err)->
						return callback(err) if err
						gutil.log "Wrote #{output_file_path}"
						callback(null)
				.catch(callback)
	
	themes = require "./themes.json"
	
	async.eachOf themes,
		(theme_path, theme_name, callback)->
			build_theme(theme_path, callback)
		(err)->
			return callback(err) if err
			debug.inspect() if enable_postcss_debug
			callback()

gulp.task 'generate-service-worker', (callback)->
	path = require 'path'
	sw_precache = require 'sw-precache'
	
	return sw_precache.write 'service-worker.js',
		staticFileGlobs: [
			'./index.html'
			'./service-worker.js'
			'./build/**/*.{js,css,png,jpg,gif,svg,eot,ttf,woff,woff2}'
			'./lib/**/*.{js,css,png,jpg,gif,svg,eot,ttf,woff,woff2}'
			'./styles/**/*.{png,jpg,gif,svg,eot,ttf,woff,woff2}' # TODO: should probably copy assets to /build/ with postcss-url
			'./styles/*.css' # TODO: should compile to /build/
			'./images/wavey-logo.svg'
			'./images/wavey-logo-512.png'
		]
		ignoreUrlParametersMatching: [/./] # fixes fontello
		# verbose: yes

gulp.task 'watch-build-and-generate-service-worker', ->
	gulp.watch 'build/**/*', gulp.series('generate-service-worker')

gulp.task 'default', gulp.parallel(
	'watch-scripts'
	'styles'
	'watch-styles'
	'watch-build-and-generate-service-worker'
)

