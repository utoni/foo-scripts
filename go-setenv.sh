#!/bin/sh
set -e

DEFAULT_GOPATH="$(realpath .)"
DEFAULT_GOARCH="${GOARCH}"
DEFAULT_GOARM="${GOARM}"
DEFAULT_GOOS="${GOOS:-linux}"

dialog \
	--backtitle "GOLANG SETENV" \
	--title "golang - setenv" \
	--form "\nSet required env vars for go." \
		25 60 16 'GOPATH:' 1 1 "${DEFAULT_GOPATH}" 1 25 25 30 \
		'GOARCH:' 2 1 "${DEFAULT_GOARCH}" 2 25 25 30 \
		'GOARM' 3 1 "${DEFAULT_GOARM}" 3 25 25 30 \
		'GOOS' 4 1 "${DEFAULT_GOOS}" 4 25 25 30 \
2>/tmp/form.$$
clear

export GOPATH="$(cat /tmp/form.$$ | head -n 1)"
export GOARCH="$(cat /tmp/form.$$ | head -n 2 | tail -n 1)"
export GOARM="$(cat /tmp/form.$$ | head -n 3 | tail -n 1)"
export GOOS="$(cat /tmp/form.$$ | head -n 4 | tail -n 1)"

echo "[*] EXPORT GOPATH=${GOPATH}"
echo "[*] EXPORT GOARCH=${GOARCH}"
echo "[*] EXPORT GOARM=${GOARM}"
echo "[*] EXPORT GOOS=${GOOS}"
echo "export GOPATH=\"$(cat /tmp/form.$$ | head -n 1)\"; export GOARCH=\"$(cat /tmp/form.$$ | head -n 2 | tail -n 1)\"; export GOARM=\"$(cat /tmp/form.$$ | head -n 3 | tail -n 1)\"; export GOOS=\"$(cat /tmp/form.$$ | head -n 4 | tail -n 1)\""


if [ "x${1}" != "x" ]; then
	echo "[*] EXEC ${*}"
	eval "${*}"
fi
