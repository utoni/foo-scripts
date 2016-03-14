#!/bin/bash


for wid in $(xdotool search --onlyvisible --sync --all --class X-terminal-emulator)
  do xdotool type --window $wid "$*"
     xdotool key --window $wid KP_Enter
done
