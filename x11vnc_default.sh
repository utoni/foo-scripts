#!/bin/bash
TIMEOUT=180
LISTEN=""

xmsg() {
if [ -x /usr/bin/zenity ]; then
  if [ -z "$2" ]; then
    /usr/bin/zenity --info --text "$1"
  else
    /usr/bin/zenity --timeout "$2" --info --text "$1"
  fi
else
  if [ -z "$2" ]; then
    /usr/bin/xmessage "$1"
  else
    /usr/bin/xmessage -timeout "$2" "$1"
  fi
fi
}

if [ -z "$DISPLAY" ]; then
  echo "$0: \$DISPLAY is not set .." >&2
  exit 1
fi

if [ ! -x /usr/bin/x11vnc ]; then
  xmsg 'x11vnc is not installed!'
  echo "$0: x11vnc is not installed!" >&2
  exit 1
fi

if [ -f ~/.vnc_srv.lock ]; then
  xmsg 'Bitte etwas Geduld, Hilfe naht!'
  exit 1
fi

xhost +
xmsg "Remotedesktop Sitzung gestartet. Innerhalb der naechsten ${TIMEOUT} Sekunden kann sich der Admin einloggen und nach dem Login den Desktop uebernehmen" ${TIMEOUT} &
touch ~/.vnc_srv.lock
if [ -z "$LISTEN" ]; then
  VNC_ARGS="-localhost"
else
  VNC_ARGS="-listen ${LISTEN}"
fi
x11vnc -shared -no6 -geometry 800x600 -timeout ${TIMEOUT} -nolookup -nopw -grabptr ${VNC_ARGS}
rm -f ~/.vnc_srv.lock
xmsg 'Die Remotedesktop Sitzung wurde beendet. Sollte es wieder einmal brennen, einfach erneut auf "Hilfe!" klicken.' 60

