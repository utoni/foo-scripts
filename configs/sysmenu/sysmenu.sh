#!/bin/sh
set -e
trap - 2

USER=toni

NOACTIVE=0
while (`true`); do
if [ ${NOACTIVE} -eq 1 ]; then
  while (`true`); do
    echo -n "."
    sleep 1
  done
  break
fi
ANWSER=$(whiptail --nocancel --output-fd 3 --title "sysmenu" --clear --menu "SYSMENU" 15 30 8 "poweroff" "" "reboot" "" "startx" "" "suspend2ram" "" "partymode" "" "hide" "" 3>&1 1>&2 2>&3)

case "${ANWSER}" in
  reboot)
    echo "reboot"
    sudo /sbin/reboot
    break;;
  poweroff)
    echo "poweroff"
    sudo /sbin/poweroff
    break;;
  suspend2ram)
    sudo /usr/sbin/s2ram --force
    break;;
  startx)
    su -l ${USER} -s /bin/bash -c '/usr/bin/startx'
    clear
    ;;
  partymode)
    sudo -u guest -- /usr/bin/startx
    clear
    ;;
  hide)
    clear
    echo -n "[SYSTEM OFFLINE] " >&2
    NOACTIVE=1
    ;;
esac

unset ANSWER
done

sleep 1
exit 0
