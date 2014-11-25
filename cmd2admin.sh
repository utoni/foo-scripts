#!/bin/bash

if [ "x${1}" != "x" ]; then
  RUN_CMDS="${1}"
else
  send2admin "cmd2admin failed"
fi

if [ "x${2}" != "x" ]; then
  send2admin "${2}"
fi

send2admin "RUN CMD: ${RUN_CMDS}"
OUT=$(bash -c "${RUN_CMDS}")
if [ $? -ne 0 ]; then
  send2admin "CMD failed!"
else
  send2admin "CMD succeeded!"
fi
send2admin "output:\n${OUT}"
exit 0
