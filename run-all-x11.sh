#!/bin/bash

TERMAPP='lxterminal'
CURRENT_WINDOW_FOCUS=$(xdotool getwindowfocus)
for wid in $(xdotool search --onlyvisible --sync --all --class ${TERMAPP}); do
	xdotool windowfocus --sync $wid
	xdotool type --window $wid "$*"
	xdotool key --window $wid KP_Enter
done
xdotool windowfocus --sync ${CURRENT_WINDOW_FOCUS}
