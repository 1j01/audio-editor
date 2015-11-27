
class @TracksArea extends E.Component
	render: ->
		{tracks, position, position_time, playing, editor} = @props
		
		drag = (range, to_time, to_track_id)=>
			sorted_tracks = editor.get_sorted_tracks tracks
			from_track = track for track in sorted_tracks when track.id is range.firstTrackID()
			to_track = track for track in sorted_tracks when track.id is to_track_id
			include_tracks =
				if sorted_tracks.indexOf(from_track) < sorted_tracks.indexOf(to_track)
					sorted_tracks.slice sorted_tracks.indexOf(from_track), sorted_tracks.indexOf(to_track) + 1
				else
					sorted_tracks.slice sorted_tracks.indexOf(to_track), sorted_tracks.indexOf(from_track) + 1
			new Range range.a, Math.max(0, to_time), [range.firstTrackID()].concat(track.id for track in include_tracks when track.id isnt range.firstTrackID())
		
		E ".tracks-area",
			onMouseDown: (e)=>
				return if e.isDefaultPrevented()
				unless e.button > 0
					e.preventDefault()
				if e.target is React.findDOMNode(@)
					e.preventDefault()
					editor.deselect()
			E ".tracks",
				key: "tracks"
				# @TODO: touch support
				# @TODO: double click to select either to the bounds of adjacent audio clips or everything on the track
				# @TODO: drag and drop the selection?
				# @TODO: better overall drag and drop feedback
				onMouseDown: (e)=>
					return unless e.button is 0
					track_content_el = closest e.target, ".track-content"
					if closest track_content_el, ".add-track, .unknown-track"
						e.preventDefault()
						editor.deselect()
						return
					unless track_content_el
						unless closest e.target, ".track-controls"
							e.preventDefault()
							editor.deselect()
						return
					e.preventDefault()
					
					time_at = (e)=>
						rect = track_content_el.getBoundingClientRect()
						(e.clientX - rect.left) / scale
					
					track_id_at = (e)=>
						track_el = closest e.target, ".track"
						if track_el and track_el.dataset.trackId
							track_el.dataset.trackId
						else
							track_els = React.findDOMNode(@).querySelectorAll ".track"
							nearest_track_el = track_els[0]
							distance = Infinity
							for track_el in track_els when track_el.dataset.trackId
								rect = track_el.getBoundingClientRect()
								_distance = Math.abs(e.clientY - (rect.top + rect.height / 2))
								if _distance < distance
									nearest_track_el = track_el
									distance = _distance
							nearest_track_el.dataset.trackId
					
					t = time_at e
					track_id = track_id_at e
					
					if e.shiftKey
						editor.select drag @props.selection, t, track_id
					else
						editor.select new Range t, t, [track_id]
					
					mouse_moved = no
					mouse_move_from_clientX = e.clientX
					window.addEventListener "mousemove", onMouseMove = (e)=>
						if Math.abs(e.clientX - mouse_move_from_clientX) > 5
							mouse_moved = yes
						if mouse_moved and @props.selection
							editor.select drag @props.selection, time_at(e), track_id_at(e)
							e.preventDefault()
					
					window.addEventListener "mouseup", onMouseUp = (e)=>
						window.removeEventListener "mouseup", onMouseUp
						window.removeEventListener "mousemove", onMouseMove
						unless mouse_moved
							editor.seek t
				
				for track in tracks
					switch track.type
						when "beat"
							E BeatTrack, {key: track.id, track, editor}
						when "audio"
							E AudioTrack, {
								key: track.id, track
								position, position_time, playing, editor
								selection: (@props.selection if @props.selection?.containsTrack track)
							}
						else
							E UnknownTrack, {key: track.id, track, editor}
				
				E AddTrack, {key: "add-track", editor}
