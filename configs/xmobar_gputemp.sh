#!/bin/bash

if [ "x$1" = "xmem" ]; then
	nvidia-smi | grep -oE '[0-9]{1,3}%\s*[0-9]{1,4}MB\s*/\s*[0-9]{1,4}MB'
else
	OUT=$(nvidia-smi | sed -n 's/\(.*\)\([0-9]\{2,3\}\)C\(.*\)/\2/p')
	if [ "x$OUT" = "x" ]; then
		echo "<fc=#FF0000>ERR</fc>"
	elif [ $OUT -gt 75 ]; then
		echo "<fc=#FF0000>$OUT</fc>°C"
	elif [ $OUT -ge 65 ]; then
		echo "<fc=#FFFF00>$OUT</fc>°C"
	elif [ $OUT -ge 50 ]; then
		echo "<fc=#00FF00>$OUT</fc>°C"
	else
		echo "$OUT°C"
	fi
fi
