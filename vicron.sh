#!/bin/sh
#
# Edit the system wide cron file
# /etc/crontab
#

SYS_CRONTAB=/etc/crontab
[ ! -x /bin/crontab -a ! -x /usr/bin/crontab ] && exit 2
[ -z "$1" ] || SYS_CRONTAB="$1"
[ -z "$EDITOR" ] && EDITOR=vi
[ -z "$PATH" ] && PATH="/bin:/sbin:/usr/bin:/usr/sbin"
TARGET_SH=$(cat ${SYS_CRONTAB} | grep -E '^SHELL=(.*)$' | sed -e 's/^SHELL=\(.*\)$/\1/' | sed -e 's/\//\\\//g')
TARGET_ENV=$(cat ${SYS_CRONTAB} | grep -E '^(.*)=(.*)$' | sed ':begin;$!N;s/\n/ /;tbegin' | sed -e 's/\//\\\//g')

if [ `id -u` -eq 0 ]; then

$EDITOR ${SYS_CRONTAB}
GREPCMD=$(grep -E '^(\s|\t)+[0-9/*]+(\s|\t)+[0-9/*]+(\s|\t)+[0-9/*]+(\s|\t)+[0-9/*]+(\s|\t)+[0-9/*]+(\s|\t)+[0-9a-zA-Z]*(\s|\t)(.*)$' ${SYS_CRONTAB})
NEWTAB=""
for line in "$GREPCMD"; do
  SEDCMD=$(echo "$line" | sed -e "s/\s*\([0-9\/\*\-]*\)\s*\([0-9\/\*\-]*\)\s*\([0-9\/\*\-]*\)\s*\([0-9\/\*\-]*\)\s*\([0-9\/\*\-]*\)\s*\([0-9A-Za-z]*\)\s*\(.*$\)/ \1 \2 \3 \4 \5 su -l \6 -s ${TARGET_SH} -c 'env ${TARGET_ENV}; \7'/")
  NEWTAB="$NEWTAB\n$SEDCMD"
done
NEWTAB="$NEWTAB\n"
echo -e "$NEWTAB" | crontab -u root -

else

crontab -u `id -un` -e

fi

exit $?
