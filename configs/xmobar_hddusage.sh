#!/bin/bash

HDD="sda"

NOUT=$(iostat | tr -s ' ' | grep -E '^(sd|hd)')
if [ "x$1" = "xread" ]; then
	OUT=$(echo "$NOUT" | grep $HDD | cut -d ' ' -f 3)
elif [ "x$1" = "xwrite" ]; then
	OUT=$(echo "$NOUT" | grep $HDD | cut -d ' ' -f 4)
fi
echo "${OUT}"
exit 0
