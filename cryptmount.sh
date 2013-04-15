#!/bin/bash
PATH="/bin:/sbin:/usr/bin:/usr/sbin"
TARGET_DIR="/media"
DATA_DIR="daten"
CRYPTED_UUIDS="9de4f43b-ce55-4bea-b152-1245fb199e1d 34a631ab-cf66-4275-a275-353ba264121a 6342ac03-2401-4485-b44d-8fbd0ef66d55 73218cdc-c38d-450d-8175-c055b3ccef47 496deb95-6e40-4813-96c9-957d56f34ba1 cb2525c4-f46f-4214-94fe-cc3090f3bb82"
BIND_DIRS="Images(A-K) Images(L-Z) Musik Fun XXX Doc Download Programme Treiber home Serien Filme(#-D) Filme(E-K) Filme(L-Z)"
CMD_MOUNT="/etc/rc.d/samba start; /etc/rc.d/vsftpd start;"
CMD_UMOUNT="/etc/rc.d/samba stop; /home/hashd/boincd stop; /etc/rc.d/vsftpd stop; /home/hlds/start.sh stop;"
CONFIG_FILE="/etc/cryptmount.conf"
LIB_FILE="/etc/rc.d/functions"
CR_NAME="hdd_crypted"

ERR_DIR='WARNUNG: Verzeichnis nicht leer/vorhanden?'
RED="\e[1;31m"
GREEN="\e[1;32m"
NC="\e[m" # No Color

[ `whoami` != "root" ] && { echo "You need uid 0 to do this, sorry $USER."; exit 2; }
[ "$SUDO_USER" != "" ] && echo "`date`: $0 started by $SUDO_USER" | wall

test -r "$CONFIG_FILE" && . "$CONFIG_FILE"
test -r "$LIB_FILE" && { test -r /etc/rc.conf && { . /etc/rc.conf; . $LIB_FILE; FANCY=true; } }

check_lock() {
nm=`basename "$0"`
pl=`ps aux | grep "$nm" | grep "/bin/bash" | wc -l`
[ $pl -gt 2 ] && return 1;
return 0
}

while(true); do
  check_lock
  [ $? -eq 0 ] && { break; }
  echo -e "${RED}Someone is using this script.${NC}"
  echo -en "${RED}*${NC} Plz wait some secs: "
  for i in 1 2 3 4 5
  do
   echo -en "."
   sleep 1
  done
  echo
done

trap "stty echo; echo; exit 3" SIGHUP SIGINT SIGTERM

status() {
test $QUIET -eq 0 && echo "LUKS status."
FAIL=0
INC=-1
for uuid in $CRYPTED_UUIDS ; do
        INC=`expr $INC + 1`
        if [ -b "/dev/disk/by-uuid/$uuid" ]; then
                test $QUIET -eq 0 && echo -e "${RED}1\t${GREEN}SUCCESS${NC}: uuid /dev/disk/by-uuid/$uuid existiert."
        else
                test $QUIET -eq 0 && echo -e "${RED}1\tFAIL${NC}: uuid /dev/disk/by-uuid/$uuid existiert nicht."
                FAIL=1
        fi
        if [ -h "/dev/$CR_NAME$INC" ]; then
                test $QUIET -eq 0 && echo -e "${RED}2\t${GREEN}SUCCESS${NC}: symlink /dev/$CR_NAME$INC existiert."
        else
                test $QUIET -eq 0 && echo -e "${RED}2\tFAIL${NC}: symlink /dev/$CR_NAME$INC existiert nicht."
                FAIL=1
        fi
        if [ -d "$TARGET_DIR/$CR_NAME$INC" ]; then
                test $QUIET -eq 0 && echo -e "${RED}3\t${GREEN}SUCCESS${NC}: dir $TARGET_DIR/$CR_NAME$INC existiert."
        else
                test $QUIET -eq 0 && echo -e "${RED}3\tFAIL${NC}: $TARGET_DIR/$CR_NAME$INC existiert nicht."
                FAIL=1
        fi
        if [ $(mount | cut -f 1 -d ' ' | grep "/dev/mapper/$CR_NAME$INC" | wc -l) -gt 0 ]; then
                test $QUIET -eq 0 && echo -e "${RED}4\t${GREEN}SUCCESS${NC}: dev /dev/mapper/$CR_NAME$INC gemountet."
        else
                test $QUIET -eq 0 && echo -e "${RED}4\tFAIL${NC}: /dev/mapper/$CR_NAME$INC nicht gemountet."
                FAIL=1
        fi
        test $QUIET -eq 0 && echo ""
done
if [ -x "$TARGET_DIR/$DATA_DIR" ]; then
        test $QUIET -eq 0 && echo -e "${GREEN}SUCCESS${NC}: $TARGET_DIR/$DATA_DIR existiert."
else
        test $QUIET -eq 0 && echo -e "${RED}FAIL${NC}: $TARGET_DIR/$DATA_DIR existiert nicht."
        FAIL=1
fi
test $FAIL -eq 1 && echo -e "${RED}Keine Partitionen entschluesselt/gemountet.${NC}"
test $FAIL -eq 0 && echo -e "\n${GREEN}LUKS Partitionen offen und gemountet.${NC}"
}

if [ "$2" == "quiet" ]; then
        QUIET=1
else
        QUIET=0
fi
test "$1" = "status" && { status; exit 0; }
test `whoami` = "root" || { echo -e "Sie sind kein ${RED}root${NC}...\nBenutzer duerfen folgenden Befehl ausfuehren:\n\t$0 [status] [quiet]"; exit 1; }
if [ "$2" == "fsck" ]; then
        FSCK=1
else
        FSCK=0
fi

checkmapper() {
cryptsetup status "$1" >/dev/null
retval=$?
test $retval -eq 0 && { return 0; }
return 1
}

openluks() {
test `lsmod|grep dm_crypt|wc -w` -gt 0 || modprobe dm_crypt
echo "Verschluesselungsmodul bereit."
echo -n "(LUKS) Passwort: "
stty -echo; read PW; stty echo
echo ""
echo "Erstelle Symlinks und oeffne LUKS..."
INC=-1
for uuid in $CRYPTED_UUIDS ; do
        INC=`expr $INC + 1`
        test -h /dev/hdd_crypted$INC && { echo -e "${RED}WARNUNG${NC}: symlink /dev/hdd_crypted$INC existiert."; }
        ln -s /dev/disk/by-uuid/$uuid /dev/hdd_crypted$INC 2>/dev/null 1>/dev/null
        test -f /dev/mapper/hdd_crypted$INC || (echo -n $PW | cryptsetup luksOpen /dev/hdd_crypted$INC hdd_crypted$INC > /dev/null 1>&1)
        if [ $? -eq 0 ]; then
                echo "Schluessel erfolgreich gelesen: Verfuegbar in /dev/mapper/hdd_crypted$INC"
                test $FSCK -eq 1 && { echo "Pruefe Dateisystem ... Abbrechen mit STRG+C"; fsck /dev/mapper/hdd_crypted$INC; }
        else
                echo -e "${RED}FEHLER${NC}: LUKS auf hdd_crypted$INC konnte nicht geoeffnet werden?!\n\t${RED}Falsches${NC} Kennwort?"
                read -p "  Fortfahren? (y/n)" -n 1 ret
                [ "$ret" == "n" ] && return 1
        fi
done
return 0
}

closeluks() {
test $FANCY && stat_busy "close luks .."
INC=-1
for uuid in $CRYPTED_UUIDS ; do
        INC=`expr $INC + 1`
          test $FANCY && { stat_busy "Closing /dev/mapper/hdd_crypted$INC .."; }
          test $FSCK -eq 1 && {  echo "HDD CRYPTED #$INC's filesystem will be checked ..." | wall; fsck -a -p -M /dev/mapper/hdd_crypted$INC &>/dev/null; sleep 2; }
          test -h /dev/hdd_crypted$INC && { rm /dev/hdd_crypted$INC; }
          cryptsetup luksClose hdd_crypted$INC &>/dev/null; test $? -ne 0 && { test $FANCY && stat_fail; continue; }
          test $FANCY && stat_done
done
}

mountmap() {
test -d $TARGET_DIR/$DATA_DIR || mkdir -p $TARGET_DIR/$DATA_DIR
INC=-1
for uuid in $CRYPTED_UUIDS ; do
        INC=`expr $INC + 1`
        test -d $TARGET/hdd_crypted$INC || mkdir -p $TARGET_DIR/hdd_crypted$INC
        test $(mount | cut -f 1 -d ' ' | grep $TARGET_DIR/hdd_crypted$INC | wc -l) -le 0 && mount /dev/mapper/hdd_crypted$INC $TARGET_DIR/hdd_crypted$INC -t auto -o nodev,rw,nosuid,nouser 2>/dev/null
        for dir in $BIND_DIRS ; do
                test $(mount | cut -f 1 -d ' ' | grep $TARGET_DIR/hdd_crypted$INC/$dir | wc -l) -le 0 && test -d $TARGET_DIR/hdd_crypted$INC/$dir && (test -d $TARGET/$DATA_DIR/$dir || mkdir $TARGET_DIR/$DATA_DIR/$dir; mount -o bind $TARGET_DIR/hdd_crypted$INC/$dir $TARGET_DIR/$DATA_DIR/$dir) 2>/dev/null
        done
done
bash -c "$CMD_MOUNT"
echo "All crypto dev's ready. (mounted by $SUDO_USER)" | wall
}

umountmap() {
echo "$USER try to unmount all crypto dev's" | wall
bash -c "$CMD_UMOUNT" 2>/dev/null
INC=-1
for uuid in $CRYPTED_UUIDS ; do
        INC=`expr $INC + 1`
        test $FANCY && stat_busy "unmount $TARGET_DIR/hdd_crypted$INC .."
        for dir in $BIND_DIRS ; do
                test -d $TARGET_DIR/hdd_crypted$INC/$dir && (umount -l $TARGET_DIR/hdd_crypted$INC/$dir; rmdir $TARGET_DIR/$DATA_DIR/$dir; test $? -ne 0 && { test $FANCY && stat_fail; FAIL=true; } )
        done
        umount -l /dev/mapper/hdd_crypted$INC > /dev/null 2>&1
        rmdir $TARGET_DIR/hdd_crypted$INC > /dev/null 2>&1
        test $? -ne 0 && { test $FANCY && stat_fail; FAIL=true; }
        test $FAIL || { test $FANCY && stat_done; }
done
test $FANCY && stat_busy "removing $TARGET_DIR/$DATA_DIR"
rmdir $TARGET_DIR/$DATA_DIR > /dev/null 2>&1
if [ $? -ne 0 ]; then
        test $FANCY && stat_fail
else
        test $FANCY && stat_done
fi
}

case "$1" in
        mount)
                echo "Partitionen werden geoeffnet ..."
                openluks
                if [ $? -eq 0 ]; then
                  echo "LUKS Partitionen werden gemounted ..."
                  mountmap
                else
                  echo -e "\n\t${RED}Falsches LUKS Kennwort ...${NC}"
                fi
        ;;
        cdir)
                echo "Partitionen werden geoeffnet ..."
                openluks
                echo "LUKS Partitionen werden gemounted ... (nur crypted dir's)"
                test -d $TARGET_DIR/$DATA_DIR || mkdir -p $TARGET_DIR/$DATA_DIR
                INC=-1
                for uuid in $CRYPTED_UUIDS ; do
                  INC=`expr $INC + 1`
                  test -d $TARGET/hdd_crypted$INC || mkdir -p $TARGET_DIR/hdd_crypted$INC
                  test $(mount | cut -f 1 -d ' ' | grep $TARGET_DIR/hdd_crypted$INC | wc -l) -le 0 && mount /dev/mapper/hdd_crypted$INC $TARGET_DIR/hdd_crypted$INC -t auto -o nodev,rw,nosuid,nouser 2>/dev/null
                done
        ;;
        umount)
                echo "Unmounting.."
                umountmap

        ;;
        open)
                echo "Open LUKS..."
                openluks
        ;;
        close)
                test $FANCY && stat_busy "umount all devs and close luks .."
                umountmap
                sleep 2
                closeluks
        ;;
        check)
                echo "Checking FS.."
                umountmap
                checkfs
                mountmap
        ;;
        checkmap)
                echo "Checking mapped devs..."
                for file in `ls /dev/mapper/`; do
                        if [ "$file" != "control" ]; then
                                echo -n "$file .. "
                                checkmapper "$file"
                                if [ $? -eq 0 ]; then
                                        echo -e "[ ${GREEN}OK${NC} ]";
                                else
                                        echo -e "[ ${RED}FAIL${NC} ]";
                                fi
                        fi
                done
        ;;
        *)
                echo -e "Usage:\t[close|check|mount|umount|status|checkmap] [fsck|quiet]"
                exit 3
        ;;
esac
