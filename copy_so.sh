#!/bin/sh

[ -z "$LDD" ] && LDD=/usr/bin/ldd
[ -z "$GREP" ] && GREP=/bin/grep

LDD_EXP='/(.*).so(|.[[:digit:]]+)*'
if [ $# -ne 2 ]; then
  echo "usage: $0 [binary] [destdir]" >&2
  exit 1
else
  BIN="${1}"
  DEST="${2}"
fi

SO_FILES=$(${LDD} ${BIN} | ${GREP} -oE ${LDD_EXP})

[ -d ${DEST} ] || mkdir -p ${DEST}
for file in ${SO_FILES}; do
  if [ ! -r ${file} ]; then
    echo "$0: $file not readable."
    continue
  fi
  libdir=$(dirname ${DEST}/${file})
  mkdir -p ${libdir}
  cp ${file} ${libdir}/
done

