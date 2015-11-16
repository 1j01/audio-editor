
class @Controls extends E.Component
	render: ->
		{playing, themes, set_theme, editor} = @props
		{play, pause, seek_to_start, seek_to_end, record, export_as} = editor
		E ".controls",
			E "span.floated", style: float: "right",
				E DropdownButton,
					title: "Export"
					menu: [
						{label: "Export as MP3", action: -> export_as "audio/mpeg"}
						{label: "Export as WAV", action: -> export_as "audio/wav"}
					]
					E "i.icon-export"
				if themes and set_theme
					E DropdownButton,
						title: "Settings"
						menu:
							for name, id of themes
								do (name, id)->
									label: name
									action: -> set_theme id
						E "i.icon-gear"
			E "button.button.play-pause",
				class: if playing then "pause" else "play"
				title: if playing then "Pause" else "Play"
				onClick: if playing then pause else play
				E "i.icon-#{if playing then "pause" else "play"}"
			E "span.linked",
				E "button.button.go-to-start",
					onClick: seek_to_start
					title: "Go to start"
					E "i.icon-go-to-start"
				E "button.button.go-to-end",
					onClick: seek_to_end
					title: "Go to end"
					E "i.icon-go-to-end"
			E "button.button.go-to-start",
				onClick: seek_to_start
				title: "Go to start"
				E "i.icon-go-to-start"
			E DropdownButton,
				mainButton: E "button.button.record",
					onClick: record
					title: "Start recording"
					E "i.icon-record"
				title: "Precording options"
				menu: [
					{label: "Record last minute", action: -> record 60}
					{label: "Record last 2 minutes", action: -> record 60 * 2}
					{label: "Record last 5 minutes", action: -> record 60 * 5}
				]
