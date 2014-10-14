#!/bin/bash

if [ "x$1" = "xread" ]; then
	OUT=$(iostat | sed -n 's/sda\s*[0-9,]*\s*\([0-9]*\).*$/\1/p')
elif [ "x$1" = "xwrite" ]; then
	OUT=$(iostat | sed -n 's/sda\s*[0-9,]*\s*[0-9,]*\s*\([0-9]*\).*$/\1/p')
else
	exit 1
fi

if [ "$OUT" -gt 5000 ]; then
	echo "<fc=#FF0000>${OUT}</fc>Kbs"
elif [ "$OUT" -gt 2000 ]; then
	echo "<fc=#FFFF00>${OUT}</fc>Kbs"
elif [ "$OUT" -gt 100 ]; then
	echo "<fc=#00FF00>${OUT}</fc>Kbs"
else
	echo "${OUT}Kbs"
fi
