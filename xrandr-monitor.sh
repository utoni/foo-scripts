#!/bin/sh

set -e

CHKSM_BIN=md5sum
MONITORS=$(xrandr --query | grep -oE '^[a-zA-Z0-9\-]{3,8} connected' | cut -d ' ' -f 1)
GET_BY_CHKSM=${1:-}
GOT_MONITOR=0

for mon in ${MONITORS}; do
	EDID=$(xrandr --props | grep "^${mon}" -A 10 | grep -oE '[a-fA-F0-9]{32}')
	EDID_CHKSM=$(printf "%s" "${EDID}" | ${CHKSM_BIN} | cut -d ' ' -f 1)

	if [ "x${GET_BY_CHKSM}" = "x${EDID_CHKSM}" ]; then
		printf "%s" "${mon}"
		GOT_MONITOR=$((${GOT_MONITOR} + 1))
	elif [ "x${GET_BY_CHKSM}" = "x" ]; then
		printf "Monitor: '%s'\n" "${mon}"
		if [ "x${EDID}" != x ]; then
			printf "[EDID]\n%s\n" "${EDID}"
			printf "Chksm: %s\n" $(printf "%s" "${EDID}" | ${CHKSM_BIN} | cut -d ' ' -f 1)
		fi
	fi
done

if [ "x${GET_BY_CHKSM}" != "x" -a ${GOT_MONITOR} -eq 0 ]; then
	printf "%s" "unknown"
	exit 1
fi
