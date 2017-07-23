#!/bin/bash

TERMAPP='x-terminal-emulator'
for wid in $(xdotool search --onlyvisible --sync --all --class ${TERMAPP}); do
	xdotool type --window $wid "$*"
	xdotool key --window $wid KP_Enter
done
