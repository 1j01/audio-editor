
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
update_from_hash = ->
	if m = location.hash.match /theme=([\w\-./]*)/
		theme = m[1]
		theme_link = document.getElementById "theme"
		theme_link.href = "styles/themes/#{theme}.css"
		
		if theme.match /elementary/
			unless hacky_interval
				hacky_interval = setInterval patch_elementary_classes, 150
				window.addEventListener "mousedown", patch_elementary_classes
				window.addEventListener "mouseup", patch_elementary_classes

window.addEventListener "hashchange", update_from_hash
update_from_hash()

set_theme = (theme)->
	location.hash = "theme=#{theme}"

tracks = [
	{clips: []}
]
document_id = (location.hash.match(/document=([\w\-./]*)/) ? [0, "d1"])[1]

undos = []
redos = []

save_tracks = ->
	render()
	localforage.setItem "#{document_id}/tracks", tracks, (err)=>
		if err
			alert "Failed to store track metadata.\n#{err.message}"
			console.error err
		else
			render()
	localforage.setItem "#{document_id}/undos", undos
	localforage.setItem "#{document_id}/redos", redos
	# @TODO: error handling

@undoable = ->
	redos = []
	undos.push JSON.parse JSON.stringify tracks
	save_tracks()

@undo = ->
	return unless undos.length
	redos.push JSON.parse JSON.stringify tracks
	tracks = undos.pop()
	save_tracks()
	load_clips()
	# @TODO: AudioEditor#update_playback()

@redo = ->
	return unless redos.length
	undos.push JSON.parse JSON.stringify tracks
	tracks = redos.pop()
	save_tracks()
	load_clips()
	# @TODO: AudioEditor#update_playback()


audio_buffers_by_clip_id = {}

@audio_buffer_for_clip = (clip_id)->
	audio_buffers_by_clip_id[clip_id]


load_clip = (clip)->
	return if audio_buffers_by_clip_id[clip.id]?
	localforage.getItem "#{document_id}/#{clip.id}", (err, array_buffer)=>
		if err
			alert "Failed to load audio data.\n#{err.message}"
			console.error err
		else if array_buffer
			actx.decodeAudioData array_buffer, (buffer)=>
				audio_buffers_by_clip_id[clip.id] = buffer
				remove_alert "Not all tracks have finished loading."
				render()
		else
			alert "An audio clip is missing from storage."
			console.warn "An audio clip is missing from storage.", clip

load_clips = ->
	for track in tracks
		for clip in track.clips
			load_clip clip

do render = ->
	React.render (E AudioEditor, {tracks, save_tracks, themes, set_theme}), document.body

localforage.getItem "#{document_id}/tracks", (err, _tracks)=>
	if err
		alert "Failed to load the document.\n#{err.message}"
		console.error err
	else if _tracks
		tracks = _tracks
		render()
		load_clips()
		
		localforage.getItem "#{document_id}/undos", (err, _undos)=>
			if err
				alert "Failed to load undo history.\n#{err.message}"
				console.error err
			else if _undos
				undos = _undos
				render()
		
		localforage.getItem "#{document_id}/redos", (err, _redos)=>
			if err
				alert "Failed to load redo history.\n#{err.message}"
				console.error err
			else if _redos
				redos = _redos
				render()

@add_clip = (file, track_index, time=0)->
	reader = new FileReader
	reader.onload = (e)=>
		array_buffer = e.target.result
		id = GUID()
		
		localforage.setItem "#{document_id}/#{id}", array_buffer, (err)=>
			if err
				alert "Failed to store audio data.\n#{err.message}"
				console.error err
			else
				# TODO: optimize by decoding and storing in parallel, but keep good error handling
				actx.decodeAudioData array_buffer, (buffer)=>
					audio_buffers_by_clip_id[id] = buffer
					clip = {time, id}
					
					# @TODO: add tracks earlier with a loading indicator and remove them if an error occurs
					# and make it so you can't edit them while they're loading (e.g. pasting audio where audio is already going to be)
					unless track_index?
						track_index = tracks.length - 1
						if tracks[track_index].clips.length > 0
							tracks.push {clips: []}
							track_index = tracks.length - 1
					
					undoable()
					tracks[track_index].clips.push clip
					save_tracks()
					# @TODO: AudioEditor#update_playback()
		, (e)=>
			alert "Audio not playable or not supported."
			console.error e
	
	reader.onerror = (e)=>
		alert "Failed to read audio file."
		console.error e
	
	reader.readAsArrayBuffer file
