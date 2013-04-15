#!/bin/sh

if [ -x /bin/cat ]; then
  cat="/bin/cat"
else
  exit 3
fi

if [ -x /usr/bin/logger ]; then
  out="/usr/bin/logger"
else
  out="echo"
fi

if [ -z "${SUBSYSTEM}" -o -z "${ACTION}" -o -z "${FIRMWARE}" -o -z "${DEVPATH}" ]; then
  $out "$0: Missing essential enviroment variable(s)"
  exit 1
fi

$out "$0: Running firmware script"
$out "$0: FIRMWARE(${FIRMWARE}) ACTION(${ACTION}) SUBSYSTEM(${SUBSYSTEM})"
FW_NAME=${FIRMWARE}
FW_PATH=

case $FW_NAME in
  /lib/firmware/*)
    break;;

  *.bin|*.hex)
    FW_PATH="/lib/firmware/${FW_NAME}"
    break;;

  *)
    FW_PATH="/lib/firmware/${FW_NAME}.bin"
    break;;
esac

if [ ! -r ${FW_PATH} ]; then
  $out "$0: Firmware ${FW_PATH} does not exist"
  exit 2
fi


case $SUBSYSTEM in
  firmware)
  break;;
  *)
    exit 1
  break;;
esac

case $ACTION in
  add)
    $out "$0: Loading ${FW_PATH} -> /sys${DEVPATH} .."
    echo 1 > /sys${DEVPATH}/loading
    $cat ${FW_PATH} > /sys${DEVPATH}/data
    echo 0 > /sys${DEVPATH}/loading
  break;;
esac

exit 0