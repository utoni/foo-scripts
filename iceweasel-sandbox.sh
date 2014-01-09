#!/bin/bash

DEF_ARCH="amd64"
DEF_SUITE="wheezy"

export DBS_OPTS
export CHROOTDIR=
export PRECMD=true
export POSTCMD=true

if [ ! -z "$1" ]; then
  CHROOTDIR="$1"
else
  CHROOTDIR="$HOME/iceweasel.sandbox"
fi

if [ ! -z "$2" ]; then
  DBS_OPTS="--arch ${DEF_ARCH} ${2} ${DEF_SUITE}"
else
  DBS_OPTS="--arch ${DEF_ARCH} ${DEF_SUITE}"
fi

add_precmd() {
  PRECMD="${PRECMD}; $1"
}

add_postcmd() {
  POSTCMD="${POSTCMD}; $1"
}

if [ ! -f "$HOME/iceweasel.sandbox.tar" ]; then
  echo "* download pkgs"
  su -- -c "/usr/sbin/debootstrap --make-tarball=${HOME}/iceweasel.sandbox.tar ${DBS_OPTS} ${CHROOTDIR} http://ftp.au.debian.org/debian/"
fi

echo "* CHROOT: $CHROOTDIR"
xhost +
if [ ! -f ${CHROOTDIR}/.stamp_installed ]; then
  su -- -c "/usr/sbin/debootstrap --unpack-tarball ${HOME}/iceweasel.sandbox.tar ${DBS_OPTS} ${CHROOTDIR} && touch ${CHROOTDIR}/.stamp_installed"
fi

read -p "mount proc? (Y/n) " -t 3 answ
if [ "x$answ" = "xY" ]; then
  add_precmd "mount -t proc proc ${CHROOTDIR}/proc"
  add_postcmd "umount ${CHROOTDIR}/proc"
fi
su -- -c "${PRECMD}; chroot ${CHROOTDIR} /bin/bash -c 'apt-get update; apt-get upgrade; apt-get install -y iceweasel; useradd -m firefox; su -l firefox -c iceweasel'; ${POSTCMD}"

read -p "delete ${CHROOTDIR} ? (Y/n) " -t 5 answ
if [ "x$answ" = "xY" ]; then
  if [ -x /usr/bin/wipe ]; then
    read -p "wipe ${CHROOTDIR}/{home,tmp} ? (Y/n) " -t 3 answ
    if [ "x$answ" = "xY" ]; then
      DOWIPE=y
    fi
  fi
  if [ "x$DOWIPE" = "xy" ]; then
    su -- -c "wipe -qrcf ${CHROOTDIR}/{home,tmp} && rm -rf ${CHROOTDIR}"
  else
    su -- -c "rm -rf ${CHROOTDIR}"
  fi
fi

