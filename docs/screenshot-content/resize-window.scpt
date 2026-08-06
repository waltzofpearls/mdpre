tell application "System Events"
	tell process "Markdown Preview"
		set frontmost to true
		set position of window 1 to {100, 100}
		set size of window 1 to {1280, 800}
	end tell
end tell
