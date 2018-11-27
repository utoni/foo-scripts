#!/bin/sh

if [ "x$1" = "xCPU" ]; then
	OUT=$(sensors | sed -n 's/^\(Physical\|Package\) id 0:\s*+\(.*\)\..*°C\s*(\(.*\)/\2/p')
elif [ "x$1" = "xMB" ]; then
	OUT=$(sensors | sed -n 's/^temp1:\s*+\(.*\)\..*°C\s*(\(.*\)/\1/p')
else
	exit 1
fi

if [ $OUT -le 50 ]; then
	echo "$OUT°C"
elif [ $OUT -le 65 ]; then
	echo "<fc=#00FF00>$OUT</fc>°C"
elif [ $OUT -le 75 ]; then
	echo "<fc=#FFFF00>$OUT</fc>°C"
else
	echo "<fc=#FF0000>$OUT</fc>°C"
fi
