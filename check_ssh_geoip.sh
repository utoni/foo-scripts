#!/bin/bash

if [ x"${BASH_VERSINFO}" = x ]; then
	echo "BASH_VERSINFO not found. Is \`/bin/bash\` a valid bash interpreter?"
	exit 1
fi
if [ "${BASH_VERSINFO}" -lt 4 ]; then
	echo "Bash version >= 4 required for declaring/using arrays/dicts."
	exit 1
fi

export DESTHOST="host.lan"
export DESTUSER="someuser"

if [ x"$1" != x ]; then
	DEST="$1"
else
	DEST="${DESTUSER}@${DESTHOST}"
fi

if [ x"$2" != x ]; then
	LOGCMD="$2"
else
	LOGCMD="logread"
fi

if [ x"$3" != x ]; then
	LOGREP="$3"
else
	LOGREP="dropbear"
fi

LINE="-------------------------"
IFS=' ';
OUT=$(ssh -o LogLevel=Error ${DEST} ${LOGCMD} | \
	sed -ne 's/.*'"${LOGREP}"'.*\s\+\([0-9\.]\+\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\).*/\1/p' | \
	uniq | tr '\n' ' ')
declare -A ORIGINS
for host in ${OUT}; do \
	echo "${host}" | grep -qoE '(192.168.|10.10.|172.)'
	[ $? -eq 0 ] && continue
	echo "${LINE}"
	echo "HOST: ${host}"
	GEOIP=$(geoiplookup "${host}")
	if [ x"${ORIGINS["${GEOIP}"]}" != x ]; then
		ORIGINS["${GEOIP}"]=$(expr ${ORIGINS["${GEOIP}"]} + 1)
	else
		ORIGINS["${GEOIP}"]=1
	fi
	echo "${GEOIP}"
done

echo "${LINE}"
echo -e "${LINE}\nEOF"
echo "${LINE}"

echo "COUNTRY STATS"
for origin in "${!ORIGINS[@]}"; do
	echo "${origin} -> ${ORIGINS["${origin}"]}"
done
