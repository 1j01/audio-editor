
@actx = new (
	window.AudioContext ?
	window.webkitAudioContext ?
	window.mozAudioContext ?
	window.oAudioContext ?
	window.msAudioContext
)

themes =
	"elementary": "elementary"
	"elementary Dark": "elementary-dark"
	"Monochrome Aqua": "retro/aqua"
	"Monochrome Green": "retro/green"
	"Monochrome Amber": "retro/amber"
	"Ambergine (aubergine + amber)": "retro/ambergine"
	"Chroma": "retro/chroma"

patch_elementary_classes = ->
	requestAnimationFrame ->
		for el in document.querySelectorAll ".track-content"
			el.classList.add "notebook"
		for el in document.querySelectorAll ".audio-editor .controls"
			el.classList.add "titlebar"
		for el in document.querySelectorAll ".menu-item"
			el.classList.add "menuitem"
		for el in document.querySelectorAll ".dropdown-menu"
			el.classList.add "window-frame"
			el.classList.add "active"
			el.classList.add "csd"

hacky_interval = null

set_theme = (theme)->
	localforage.setItem "theme", theme
	
	theme_link = document.getElementById "theme"
	theme_link.href = "styles/themes/#{theme}.css"
	
	if theme.match /elementary/
		unless hacky_interval
			hacky_interval = setInterval patch_elementary_classes, 150
			window.addEventListener "mousedown", patch_elementary_classes
			window.addEventListener "mouseup", patch_elementary_classes
			window.addEventListener "keydown", patch_elementary_classes

localforage.getItem "theme", (err, theme)->
	set_theme theme if theme

@render = ->
	document_id = (location.hash.match(/document=([\w\-./]*)/) ? [0, "default"])[1]
	React.render (E AudioEditor, {key: document_id, document_id, themes, set_theme}), document.body

window.addEventListener "hashchange", render
render()
