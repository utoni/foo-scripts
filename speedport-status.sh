#!/bin/sh

WGET="/usr/bin/wget"
PASS="$3"
COOKIES="$4"
IP="$5"


export WGET
export IP
export COOKIES

run_wget_login() {
  URL="$1"
  REF="$2"
  touch ${COOKIES}
  chmod 0600 ${COOKIES}
  ${WGET} "$URL" --referer="$REF" --post-data="pws=${PASS}" --save-cookies ${COOKIES} --keep-session-cookies -O /dev/null -q
  return $?
}

run_wget_qry() {
  URL="$1"
  REF="$2"
  PST="$3"

  if [ ! -z "$REF" ]; then
    ARGS="--referer=$REF"
  fi
  if [ ! -z "$PST" ]; then
    ARGS="$ARGS --post-data=$PST"
  fi

  ${WGET} "$URL" --load-cookies ${COOKIES} -O - -q $ARGS
  return $?
}



wget_cleanup() {
  rm -f ${COOKIES}
}

w502v_action() {
case "$1" in
  login)
    run_wget_login "http://speedport.ip/cgi-bin/login.cgi" "http://speedport.ip/hcti_start_passwort.stm"
    retval=$?
    if [ $retval -eq 4 ]; then
      echo "Unknown hostname. Let speedport.ip point to your speedport router to get this working." >&2
    fi
    return $retval
  ;;
  status)
    w502v_action login
    run_wget_qry "http://speedport.ip/hcti_status_dsl.stm" | grep -E '^var\s(.*);$'
    retval=$?
    if [ $retval -eq 1 ]; then
      echo "Could not get status information. Is your Password correct?" >&2
    fi
    return $retval
  ;;
  restart)
    w502v_action login
    run_wget_qry "http://speedport.ip/cgi-bin/restart.cgi" "http://speedport.ip/hcti_hilfsmittel_reboot.stm" " " >/dev/null
    retval=$?
    return $retval
  ;;
  *)
    echo "$0: Unknown action" >&2
    break
  ;;
esac
}

usage() {
  echo
  echo "* `basename $0`: [router] [status|restart] [pass] [cookies-file] [ip]"
}

case "$1" in
  w502v|502v|502|W502V|502V)
    w502v_action "$2"
    wget_cleanup
  ;;
  *)
    usage
  ;;
esac

exit 0
