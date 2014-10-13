#!/bin/sh

if [ "x$1" = "xCPU" ]; then
	TYP="CPU"
	OUT=$(sensors | sed -n 's/^Core 0:\s*+\(.*\).0°C\s*(\(.*\)/\1/p')
elif [ "x$1" = "xMB" ]; then
	TYP="MB"
	OUT=$(sensors | sed -n 's/^temp3:\s*+\(.*\).0°C\s*(\(.*\)/\1/p')
fi

if [ $OUT -gt 70 ]; then
	echo "$TYP: <fc=#FF0000>$OUT</fc>°C"
elif [ $OUT -gt 60 ]; then
	echo "$TYP: <fc=#FFFF00>$OUT</fc>°C"
else
	echo "$TYP: <fc=#00FF00>$OUT</fc>°C"
fi
exit $?
