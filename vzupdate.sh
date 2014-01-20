#!/bin/sh
################################################################
# Update Script for VZ Container on Debian based Distributions #
################################################################

VES=$( cat /proc/vz/veinfo | awk '{ print $1 }' )

[ -f /etc/debian_version ] || { echo "$0: not a debian based distro."; exit 1; }

for ve in $VES; do
  echo "-> UPDATE CT:$ve"
  [ $ve -eq 0 ] && { apt-get update; apt-get upgrade; break; }
  [ -r /etc/vz/conf/$ve.conf ] || { echo "$0: fail."; continue; }

  VEID=$ve
  . /etc/vz/conf/$VEID.conf
  [ -f $VE_PRIVATE/etc/debian_version ] || { echo "$0: CT$VEID is not a debian based distro."; continue; }
  [ -z $NAME ] || echo "-> NAME $NAME"

  vzctl exec $VEID "apt-get update; apt-get -y upgrade;"
done