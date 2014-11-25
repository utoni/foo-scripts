#!/bin/bash

if [ "x$1" = "xread" ]; then
	OUT=$(sudo iotop -b -n 1 -P -k -qq | sed -n 's/^Total DISK READ:\s*\([0-9]*\)\..*$/\1/p')
elif [ "x$1" = "xwrite" ]; then
	OUT=$(sudo iotop -b -n 1 -P -k -qq | sed -n 's/^.*Total DISK WRITE:\s*\([0-9]*\)\..*$/\1/p')
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
