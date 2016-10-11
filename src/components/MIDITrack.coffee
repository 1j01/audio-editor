
{E, Component} = require "../helpers.coffee"
Track = require "./Track.coffee"
MIDINotes = require "./MIDINotes.coffee"
audio_clips = require "../audio-clips.coffee"
Range = require "../Range.coffee"

module.exports =
class MIDITrack extends Component
	render: ->
		{track, selection, scale, editor} = @props
		{notes, muted, pinned} = track
		
		E Track, {track, editor},
			E ".midi-trackstuff",
				style:
					position: "relative"
					height: 80 # = canvas height
					boxSizing: "content-box"
				E MIDINotes, {scale, notes, editor}
				if selection?
					E ".selection",
						key: "selection"
						className: ("cursor" if selection.end() is selection.start())
						style:
							left: scale * selection.start()
							width: scale * (selection.end() - selection.start())
