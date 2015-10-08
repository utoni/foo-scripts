#!/bin/sh

echo -n "BAT:"
OUT=$(acpi -b | sed -n 's/Battery 0:\(.*\), \(.*\)%\(.*\)/\2/p')

if [ $OUT -lt 10 ]; then
	echo "<fc=#FF0000>$OUT</fc>%"
elif [ $OUT -lt 50 ]; then
	echo "<fc=#FFFF00>$OUT</fc>%"
elif [ $OUT -lt 80 ]; then
	echo "<fc=#00FF00>$OUT</fc>%"
else
	echo "$OUT%"
fi
