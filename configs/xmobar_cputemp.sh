#!/bin/sh

if [ "x$1" = "xCPU" ]; then
	sensors | sed -n 's/^CPU Temperature:\s*+\(.*\)°C\s*(\(.*\)/CPU TEMP: \1°C/p'
elif [ "x$1" = "xMB" ]; then
	sensors | sed -n 's/^MB Temperature:\s*+\(.*\)°C\s*(\(.*\)/MB TEMP: \1°C/p'
fi
exit $?
