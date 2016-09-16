
fs = require("fs")
postcss = require("postcss")
atImport = require("postcss-import")

build_theme = (theme_name, theme_path)->
	input_file_path = "styles/themes/#{theme_path}"
	output_file_path = "build/themes/#{theme_path}"
	css = fs.readFileSync(input_file_path, "utf8")
	
	postcss()
		.use(atImport())
		.process css,
			from: input_file_path
		.then (result)->
			fs.writeFileSync(output_file_path, result.css, "utf8")
			console.log "Wrote #{output_file_path}"

# TODO: dry between this and build.coffee (probably save a JSON file)
themes =
	"elementary": "elementary.css"
	"elementary Dark": "elementary-dark.css"
	"Monochrome Aqua": "retro/aqua.css"
	"Monochrome Green": "retro/green.css"
	"Monochrome Amber": "retro/amber.css"
	"Ambergine (aubergine + amber)": "retro/ambergine.css"

for theme_name, theme_path of themes
	build_theme(theme_name, theme_path)
