
class @AudioEditor extends E.Component
	
	copy_of = (o)-> JSON.parse JSON.stringify o
	
	constructor: ->
		@state =
			tracks: [
				{
					id: "beat-track"
					type: "beat"
					muted: yes
					pinned: yes
				}
			]
			undos: []
			redos: []
			playing: no
			track_sources: []
			position: null
			position_time: null
			selection: null
	
	@document_version: 1
	@stuff_version: 1
	
	save: ->
		{document_id} = @props
		{tracks, selection, undos, redos} = @state
		doc = {
			version: AudioEditor.document_version
			state: {tracks, selection}
			undos, redos
		}
		localforage.setItem "document:#{document_id}", doc, (err)=>
			if err
				InfoBar.warn "Failed to save the document.\n#{err.message}"
				console.error err
			else
				render()
	
	load: ->
		{document_id} = @props
		localforage.getItem "document:#{document_id}", (err, doc)=>
			if err
				InfoBar.warn "Failed to load the document.\n#{err.message}"
				console.error err
			else if doc
				if not doc.version?
					InfoBar.warn "This document was created before document storage was even versioned. It cannot be loaded."
					return
				if doc.version > AudioEditor.document_version
					InfoBar.warn "This document was created with a later version of the editor. Reload to get the latest version."
					return
				if doc.version < AudioEditor.document_version
					# upgrading code should go here
					# for backwards compatible changes, the version number can simply be bumped
					InfoBar.warn "This document was created with an earlier version of the editor. There is no upgrade path as of yet, sorry."
					return
				{state, undos, redos} = doc
				{tracks, selection} = state
				@setState {tracks, undos, redos}
				@select Range.fromJSON selection if selection?
	
	undoable: (fn)->
		{tracks, selection, undos, redos} = @state
		tracks = copy_of tracks
		undos = copy_of undos
		redos = []
		undos.push
			tracks: copy_of tracks
			selection: copy_of selection
		fn tracks
		@setState {tracks, undos, redos}
	
	undo: ->
		{tracks, selection, undos, redos} = @state
		return unless undos.length
		tracks = copy_of tracks
		undos = copy_of undos
		redos = copy_of redos
		redos.push
			tracks: copy_of tracks
			selection: copy_of selection
		{tracks, selection} = undos.pop()
		@setState {tracks, undos, redos}
		@select Range.fromJSON selection if selection?
	
	redo: ->
		{tracks, selection, undos, redos} = @state
		return unless redos.length
		tracks = copy_of tracks
		undos = copy_of undos
		redos = copy_of redos
		undos.push
			tracks: copy_of tracks
			selection: copy_of selection
		{tracks, selection} = redos.pop()
		@setState {tracks, undos, redos}
		@select Range.fromJSON selection if selection?
	
	# @TODO: soft undo/redo
	
	get_max_length: ->
		{tracks} = @state
		
		max_length = 0
		for track in tracks when track.type is "audio"
			for clip in track.clips
				audio_buffer = AudioClip.audio_buffers[clip.audio_id]
				if audio_buffer
					max_length = Math.max max_length, clip.time + clip.length
				else
					InfoBar.warn "Not all tracks have finished loading."
					return
		
		max_length
	
	get_current_position: ->
		@state.position +
			if @state.playing
				actx.currentTime - @state.position_time
			else
				0
	
	seek: (time)=>
		if isNaN time
			InfoBar.warn "Tried to seek to invalid time: #{time}"
			return
		
		max_length = @get_max_length()
		
		if @state.playing and max_length? and time < max_length
			@play_from time
		else
			@pause()
			@setState
				position_time: actx.currentTime
				position: Math.max 0, time
	
	seek_to_start: =>
		@seek 0
	
	seek_to_end: =>
		end = @get_max_length()
		return unless end?
		@seek end
	
	play: =>
		@play_from @state.position ? 0
	
	play_from: (from_time)=>
		@pause() if @state.playing
		
		max_length = @get_max_length()
		return unless max_length?
		
		if from_time >= max_length or from_time < 0
			from_time = 0
		
		@setState
			tid: setTimeout @pause, (max_length - from_time) * 1000 + 20
			# NOTE: an extra few ms because it shouldn't fade out prematurely
			# (even though might sound better, it might lead you to believe
			# your audio doesn't need a brief fade out at the end when it does)
			
			position_time: actx.currentTime
			position: from_time
			
			playing: yes
			track_sources: @_start_playing from_time, actx
	
	_start_playing: (from_time, actx)->
		include_metronome = not (actx instanceof OfflineAudioContext)
		
		{tracks} = @state
		
		for track in tracks when not track.muted
			switch track.type
				when "beat"
					unless include_metronome
						# @TODO: metronome
						continue
				when "audio"
					for clip in track.clips
						source = actx.createBufferSource()
						source.gain = actx.createGain()
						source.buffer = AudioClip.audio_buffers[clip.audio_id]
						source.connect source.gain
						source.gain.connect actx.destination
						# source.gain.gain.value = if track.muted then 0 else 1
						
						# @TODO: maybe rename clip.time to clip.start_time or clip.start
						start_time = Math.max(0, clip.time - from_time)
						starting_offset_into_clip = Math.max(0, from_time - clip.time) + clip.offset
						length_to_play_of_clip = clip.length - Math.max(0, from_time - clip.time)
						
						if length_to_play_of_clip > 0
							source.start actx.currentTime + start_time, starting_offset_into_clip, length_to_play_of_clip
							source
	
	pause: =>
		clearTimeout @state.tid
		for track_sources in @state.track_sources
			for source in track_sources
				source?.stop actx.currentTime + 1.0
				source?.gain.gain.value = 0
		@setState
			position_time: actx.currentTime
			position: @get_current_position()
			playing: no
			track_sources: []
	
	update_playback: =>
		if @state.playing
			@seek @get_current_position()
	
	select: (selection)=>
		@setState {selection}
	
	deselect: =>
		@select null
	
	select_all: =>
		{tracks} = @state
		@select new Range 0, @get_max_length(), 0, tracks.length - 1
	
	select_up: =>
		{selection} = @state
		above = (track_index)-> Math.max(track_index - 1, 0)
		@select new Range selection.start(), selection.end(), above(selection.startTrackIndex()), above(selection.endTrackIndex())
	
	select_down: =>
		{selection, tracks} = @state
		below = (track_index)-> Math.min(track_index + 1, tracks.length)
		@select new Range selection.start(), selection.end(), below(selection.startTrackIndex()), below(selection.endTrackIndex())
	
	delete: =>
		{selection} = @state
		return unless selection?.length()
		
		@undoable (tracks)=>
			collapsed = selection.collapse tracks
			@select collapsed
			@seek collapsed.start()
	
	copy: =>
		{selection, tracks} = @state
		return unless selection?.length()
		localforage.setItem "clipboard", selection.contents(tracks), (err)=>
			if err
				InfoBar.warn "Failed to store clipboard data.\n#{err.message}"
				console.error err
	
	cut: =>
		@copy()
		@delete()
	
	paste: =>
		localforage.getItem "clipboard", (err, clipboard)=>
			if err
				InfoBar.warn "Failed to load clipboard data.\n#{err.message}"
				console.error err
			else if clipboard?
				
				if not clipboard.version?
					InfoBar.warn "The clipboard data was copied before clipboard data was versioned. It cannot be pasted."
					return
				if clipboard.version > AudioEditor.stuff_version
					InfoBar.warn "The clipboard data was copied from a later version of the editor. Reload to get the latest version."
					return
				if clipboard.version < AudioEditor.stuff_version
					# upgrading code should go here
					# for backwards compatible changes, the version number can simply be bumped
					InfoBar.warn "The clipboard data was copied from an earlier version of the editor. There is no upgrade path as of yet, sorry."
					return
				
				@undoable (tracks)=>
					{selection} = @state
					if selection?
						# @TODO: handle excess selected tracks better
						# (currently it collapses the entire selection, but only inserts as many rows as are in the clipboard)
						collapsed = selection.collapse tracks
						after = Range.insert clipboard, tracks, collapsed.start(), collapsed.startTrackIndex()
					else
						after = Range.insert clipboard, tracks, 0, tracks.length
					@select after
	
	insert: (stuff, insertion_position, insertion_track_start_index)->
		@undoable (tracks)=>
			Range.insert stuff, tracks, insertion_position, insertion_track_start_index
	
	set_track_prop: (track_id, prop, value)->
		@undoable (tracks)=>
			for track in tracks when track.id is track_id
				track[prop] = value
	
	mute_track: (track_id)=>
		@set_track_prop track_id, "muted", on
	
	unmute_track: (track_id)=>
		@set_track_prop track_id, "muted", off
	
	pin_track: (track_id)=>
		@set_track_prop track_id, "pinned", on
	
	unpin_track: (track_id)=>
		@set_track_prop track_id, "pinned", off
	
	remove_track: (track_id)=>
		@undoable (tracks)=>
			{selection} = @state
			for track, track_index in tracks when track.id is track_id by -1
				tracks.splice track_index, 1
				if selection?.containsTrackIndex track_index
					if selection.startTrackIndex() is selection.endTrackIndex()
						@deselect()
					else
						@select new Range selection.start(), selection.end(), selection.startTrackIndex(), selection.endTrackIndex() - 1
	
	add_clip: (file, at_selection)->
		{document_id} = @props
		if at_selection
			{selection} = @state
			return unless selection?
		reader = new FileReader
		reader.onload = (e)=>
			array_buffer = e.target.result
			clip = {id: GUID(), audio_id: GUID(), time: 0}
			
			localforage.setItem "audio:#{clip.audio_id}", array_buffer, (err)=>
				if err
					InfoBar.warn "Failed to store audio data.\n#{err.message}"
					console.error err
				else
					# @TODO: optimize by decoding and storing in parallel, but keep good error handling
					actx.decodeAudioData array_buffer, (buffer)=>
						AudioClip.audio_buffers[clip.audio_id] = buffer
						
						clip.length = buffer.length / buffer.sampleRate
						clip.offset = 0
						
						stuff = {version: AudioEditor.stuff_version, rows: [[clip]], length: clip.length}
						if at_selection
							@insert stuff, selection.start(), selection.startTrackIndex()
						else
							@insert stuff, 0, @state.tracks.length
			, (e)=>
				InfoBar.warn "Audio not playable or not supported."
				console.error e
		
		reader.onerror = (e)=>
			InfoBar.warn "Failed to read audio file."
			console.error e
		
		reader.readAsArrayBuffer file
	
	export_as: (file_type)=>
		sample_rate = 44100
		length = @get_max_length()
		number_of_channels = if file_type is "mp3" then 1 else 2
		oactx = new OfflineAudioContext number_of_channels, sample_rate * length, sample_rate
		@_start_playing 0, oactx
		
		forceDownload = (blob, filename)->
			url = (window.URL ? window.webkitURL).createObjectURL(blob)
			a = document.createElement "a"
			a.href = url
			a.download = filename ? "output.wav"
			a.click()
			# click = new CustomEvent "click"
			# a.dispatchEvent click
		
		oactx.startRendering()
			.then (rendered_audio_buffer)=>
				switch file_type
					when "wav", "mp3"
						worker = new Worker "lib/export/wav/recorderWorker.js"
						
						# get it started and send some config data...
						worker.postMessage
							command: "init"
							config:
								numChannels: number_of_channels
								sampleRate: oactx.sampleRate
						
						# pass it the full buffer...
						worker.postMessage
							command: "record"
							buffer:
								for i in [0...number_of_channels]
									rendered_audio_buffer.getChannelData i
						
						# ask it to export the WAV...
						worker.postMessage
							command: "exportWAV"
							type: "audio/wav"
						
						# when it's done...
						worker.onmessage = (e)=>
							switch file_type
								when "wav"
									forceDownload e.data, "export.#{file_type}"
								when "mp3"
									# console.log "got WAV data", e.data
									
									encode64 = (buffer)->
										binary = ""
										bytes = new Uint8Array buffer
										for i in [0..bytes.byteLength]
											binary += String.fromCharCode bytes[i]
										global.btoa binary
									
									parse_wav_meta_data = (wav_uint8_array)->
										# console.log "parse_wav_meta_data", wav_uint8_array
										read_int = (i, bytes)->
											val = 0
											shft = 0
											while bytes
												val += wav_uint8_array[i] << shft
												shft += 8
												i++
												bytes--
											val
										
										throw new Error "Invalid compression code, not PCM" if read_int(20, 2) isnt 1
										throw new Error "Invalid number of channels, not 1" if read_int(22, 2) isnt 1
										
										sampleRate: read_int 24, 4
										bitsPerSample: read_int 34, 2
										samples: wav_uint8_array.subarray 44
									
									Uint8ArrayToFloat32Array = (u8a)->
										f32a = new Float32Array u8a.length
										for i in [0..u8a.length]
											value = u8a[i << 1] + (u8a[(i << 1) + 1] << 8)
											value |= ~0x7FFF if value >= 0x8000
											f32a[i] = value / 0x8000
										f32a
									
									transcoderWorker = new Worker "lib/export/mp3/mp3Worker.js"
									
									file_reader = new FileReader
									
									file_reader.onload = (e)->
										
										wav_uint8_array = new Uint8Array @result
										wav_meta_data = parse_wav_meta_data wav_uint8_array
										
										transcoderWorker.postMessage
											cmd: "init"
											config:
												mode: 3
												channels: 1
												samplerate: wav_meta_data.sampleRate
												bitrate: wav_meta_data.bitsPerSample
										
										transcoderWorker.postMessage
											cmd: "encode"
											buf: Uint8ArrayToFloat32Array wav_meta_data.samples
										
										transcoderWorker.postMessage
											cmd: "finish"
										
										transcoderWorker.onmessage = (e)->
											if e.data.cmd == "data"
												# console.log "Done converting to MP3"
												
												mp3Blob = new Blob [new Uint8Array e.data.buf], type: "audio/mp3"
												
												forceDownload mp3Blob, "export.#{file_type}"
									
									file_reader.readAsArrayBuffer e.data
					else
						InfoBar.warn "Exporting as #{file_type.toUpperCase()} is not supported"

	
	componentDidUpdate: (last_props, last_state)=>
		{document_id} = @props
		{tracks, selection, undos, redos} = @state
		
		if (
			tracks isnt last_state.tracks or
			selection isnt last_state.selection or
			undos isnt last_state.undos or
			redos isnt last_state.redos
		)
			@save()
		
		if tracks isnt last_state.tracks
			@update_playback()
			AudioClip.load_clips tracks
	
	componentDidMount: =>
		
		@load()
		
		window.addEventListener "keydown", @keydown_listener = (e)=>
			return if e.defaultPrevented
			return if e.altKey
			
			if e.ctrlKey
				switch e.keyCode
					when 65 # A
						@select_all() unless e.shiftKey
					when 83 # S
						if e.shiftKey then @TODO.save_as() else @TODO.save()
					when 79 # O
						@TODO.open() unless e.shiftKey
					when 78 # N
						@TODO.new() unless e.shiftKey
					when 88 # X
						@cut() unless e.shiftKey
					when 67 # C
						@copy() unless e.shiftKey
					when 86 # V
						@paste() unless e.shiftKey
					when 90 # Z
						if e.shiftKey then @redo() else @undo()
					when 89 # Y
						@redo() unless e.shiftKey
					else
						return # don't prevent default
			else
				switch e.keyCode
					# @TODO: media keys?
					when 32 # Spacebar
						unless e.target.tagName.match /button/i
							if @state.playing
								@pause()
							else
								@play()
					when 46, 8 # Delete, Backspace
						@delete()
					when 82 # R
						@TODO.record()
					# @TODO: finer control as well
					# @TODO: move selection left/right?
					when 37 # Left
						@seek @get_current_position() - 1
					when 39 # Right
						@seek @get_current_position() + 1
					when 38, 33 # Up, Page Up
						@select_up()
					when 40, 34 # Down, Page Down
						@select_down()
					when 36 # Home
						@seek_to_start()
					when 35 # End
						@seek_to_end()
					else
						return # don't prevent default
			
			e.preventDefault()
	
	componentWillUnmount: ->
		@pause()
		window.removeEventListener "keydown", @keydown_listener
	
	render: ->
		{tracks, selection, position, position_time, playing} = @state
		{themes, set_theme} = @props
		
		E ".audio-editor",
			className: {playing}
			tabIndex: 0
			style: outline: "none"
			onMouseDown: (e)=>
				return if e.isDefaultPrevented()
				e.preventDefault()
				React.findDOMNode(@).focus()
			onDragOver: (e)=>
				return if e.isDefaultPrevented()
				e.preventDefault()
				e.dataTransfer.dropEffect = "copy"
				@deselect()
			onDrop: (e)=>
				return if e.isDefaultPrevented()
				e.preventDefault()
				for file in e.dataTransfer.files
					@add_clip file
			E Controls, {playing, editor: @, themes, set_theme, key: "controls"}
			E "div",
				key: "infobar"
				E InfoBar # @TODO, ref: (@infobar)=>
			E Tracks, {tracks, selection, position, position_time, playing, editor: @, key: "tracks"}
