#!/bin/bash

MSG_PREFIX="[AUTO_MSG]"
RC_PREFIX="/etc/sendxmpprc"
DEFAULT_REC="/etc/default/send2admin"
RET=0

if [ -r ${DEFAULT_REC} ]; then
  . ${DEFAULT_REC}
fi
if [ "x${RECIPIENT}" = "x" ]; then
  RECIPIENT="${2}"
fi

if [ "x${DISPLAY}" != "x" ]; then
  USEX=1
else
  USEX=0
fi

if [ "x${USER}" != "x" ]; then
  if [ -r "${RC_PREFIX}.${USER}" ]; then
    SX_ARGS=" -f ${RC_PREFIX}.${USER}"
  fi
fi

if [ "x${MSG_PREFIX}" != "x" ]; then
  MSG_PREFIX="${MSG_PREFIX}: "
fi
if [ "x${1}" != "x" -a "x${RECIPIENT}" != "x" ]; then
  echo -en "${MSG_PREFIX}${1}" | sendxmpp -t${SX_ARGS} ${RECIPIENT}
  RET=$?
else
  if [ $USEX -eq 1 ]; then
    xmessage "sendxmpp error: syntax: $0 [TEXT] [RECIPIENT]"
  else
    echo "sendxmpp error: syntax: $0 [TEXT] [RECIPIENT]" >&2
  fi
  RET=128
fi

exit $RET
