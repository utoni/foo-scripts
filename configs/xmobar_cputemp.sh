#!/bin/sh

if [ "x$1" = "xCPU" ]; then
	OUT=$(sensors | sed -n 's/^CPU Temperature:\s*+\(.*\)\..*°C\s*(\(.*\)/\1/p')
elif [ "x$1" = "xMB" ]; then
	OUT=$(sensors | sed -n 's/^MB Temperature:\s*+\(.*\)\..*°C\s*(\(.*\)/\1/p')
else
	exit 1
fi

if [ $OUT -le 60 ]; then
	echo "$OUT°C"
elif [ $OUT -le 75 ]; then
	echo "<fc=#00FF00>$OUT</fc>°C"
elif [ $OUT -le 85 ]; then
	echo "<fc=#FFFF00>$OUT</fc>°C"
else
	echo "<fc=#FF0000>$OUT</fc>°C"
fi
