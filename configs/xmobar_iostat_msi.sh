#!/bin/sh

OUT=$(dstat -dD total --noheaders --noupdate --integer 1 1 | tail -n 1)
# | sed -n 's/^\s*\([0-9]*[[:alpha:]]*\).*$/__\1___/p'

READ=$(echo $OUT | sed -n 's/^\s*\([0-9]*[[:alpha:]]*\).*$/\1/p')
WRITE=$(echo $OUT | sed -n 's/^\s*[0-9]*[[:alpha:]]*\s*\([0-9]*[[:alpha:]]*\)$/\1/p')
BAT=$(cat /sys/class/power_supply/ADP1/online)


outio() {
local lc
if [ $BAT -ne 1 ]; then
	echo "[DISABLED]"
	exit 0
fi
lc=$(echo "$1" | cut -c $((${#1})))
if [ $lc = "k" ]; then
	echo -n '<fc=#FFFF00>'
elif [ $lc = "B" ]; then
	echo -n '<fc=#00FF00>'
elif [ $lc = "M" ]; then
	echo -n '<fc=#FF0000>'
else
	echo -n '<fc=#FFFFFF>'
fi
echo -n "${1}</fc>"
}

outio "${READ}"
echo -n ' | '
outio "${WRITE}"
echo

exit $?
