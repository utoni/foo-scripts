#!/bin/sh

rm -f /tmp/screenshot.png
scrot -s /tmp/screenshot.png && xclip -selection clipboard -t image/png -i /tmp/screenshot.png
#scrot -s /tmp/screenshot.png && xclip -t image/png -i /tmp/screenshot.png
