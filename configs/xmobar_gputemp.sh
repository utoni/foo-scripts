#!/bin/bash

if [ "x$1" = "xmem" ]; then
	echo -ne "GPU(MEM): "
	OUT=$(nvidia-smi | sed -n 's/.*\s\([0-9]\{1,3\}\)\%\s.*/\1/p')
else
	echo -ne "GPU(TMP): "
	OUT=$(nvidia-smi | sed -n 's/\(.*\)\([0-9]\{2,3\}\)C\(.*\)/\2/p')
fi
if [ "x$OUT" = "x" ]; then
	echo "<fc=#FF0000>ERR</fc>"
fi
for tmp in $OUT; do
	if [ $tmp -gt 75 ]; then
		echo -ne "<fc=#FF0000>$tmp</fc>°C"
	elif [ $tmp -ge 65 ]; then
		echo -ne "<fc=#FFFF00>$tmp</fc>°C"
	elif [ $tmp -ge 50 ]; then
		echo -ne "<fc=#00FF00>$tmp</fc>°C"
	else
		if [ "x$1" = "xmem" ]; then
			echo -ne "$tmp% "
		else
			echo -ne "$tmp°C "
		fi
	fi
done
