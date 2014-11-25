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

export CHROOTKILL="for pid in $(lsof -t ${CHROOTDIR} 2>/dev/null | tr '\n' ' '); do echo -n "."; kill -SIGTERM "\$pid"; done; echo"

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
  echo "* DEBOOTSTRAP"
  su -- -c "/usr/sbin/debootstrap --unpack-tarball ${HOME}/iceweasel.sandbox.tar ${DBS_OPTS} ${CHROOTDIR}; touch ${CHROOTDIR}/.stamp_installed"
else
  echo "* INSTALLED"
fi

if [ $(lsof -t ${CHROOTDIR} 2>/dev/null | wc -l) -ne 0 ]; then
  echo "* Running instance found"
  read -p "kill instance? (Y/n) " -t 3 answ
  if [ "x$answ" = "xY" ]; then
    echo -n "* SIGTERM all processes"
    su -- -c "$CHROOTKILL"
  else
    echo "* abort"
    exit 1
  fi
fi

read -p "mount proc? (Y/n) " -t 3 answ
if [ "x$answ" = "xY" ]; then
  add_precmd "mount -t proc proc ${CHROOTDIR}/proc"
  add_postcmd "umount ${CHROOTDIR}/proc"
fi
echo "* CHROOT"
su -- -c "${PRECMD}; chroot ${CHROOTDIR} /bin/bash -c 'apt-get update; apt-get upgrade; apt-get install -y iceweasel; useradd -m firefox; su -l firefox -c iceweasel'; ${CHROOTKILL}; ${POSTCMD}"

read -p "delete ${CHROOTDIR} ? (Y/n) " -t 5 answ
if [ "x$answ" = "xY" ]; then
  if [ -x /usr/bin/wipe ]; then
    read -p "wipe ${CHROOTDIR}/{home,tmp} ? (Y/n) " -t 3 answ
    if [ "x$answ" = "xY" ]; then
      DOWIPE=y
    fi
  fi
  add_postcmd "umount ${CHROOTDIR}/proc"
  if [ "x$DOWIPE" = "xy" ]; then
    echo "* WIPE"
    su -- -c "${CHROOTKILL}; ${POSTCMD}; wipe -qrcf ${CHROOTDIR}/{home,tmp}; rm -rf ${CHROOTDIR}"
  else
    echo "* RM"
    su -- -c "${CHROOTKILL}; ${POSTCMD}; rm -rf ${CHROOTDIR}"
  fi
fi

