#!/bin/bash

SOC_PORT=4242

while `netstat -l4n | grep -qoE "^tcp(.*):${SOC_PORT}"`; do
	NEXT_PORT=$(expr ${SOC_PORT} + 1)
	echo "${SOC_PORT} isnt available, trying ${NEXT_PORT}"
	SOC_PORT=${NEXT_PORT}
done

if [ $# -ne 3 ]; then
	echo "$0: [IRC_HOST] [IRC_PORT] [IRC_NICK]"
	exit 1
fi
IRC_HOST="$1"
IRC_PORT="$2"
IRC_NICK="$3"

sudo iptables -A INPUT -p tcp '!' -s 127.0.0.1 --dport ${SOC_PORT} -j REJECT
socat TCP4-LISTEN:${SOC_PORT},reuseaddr,range=127.0.0.1/32 SOCKS4A:localhost:${IRC_HOST}:${IRC_PORT},socksport=9050 &
SOC_PID=$!
echo "socat pid ${SOC_PID}"
irssi -c localhost -p ${SOC_PORT} -n ${IRC_NICK}
echo "kill ${SOC_PID}"
kill -SIGTERM ${SOC_PID} 2>/dev/null
wait ${SOC_PID}
sudo iptables -D INPUT -p tcp '!' -s 127.0.0.1 --dport ${SOC_PORT} -j REJECT
