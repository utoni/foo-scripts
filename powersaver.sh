#!/bin/bash
#
# (cc:by-sa) 2007 Marco Gabriel, http://www.marcogabriel.com/
# modified by Toni U. (matzeton@googlemail.com)
#    This Script uses nmap && vnstat!
# Powersaver.sh

###
# CONFIG
###

# filename of the statusfiles
STATUSFILE="/tmp/powersaver-status"
POWERFILE="/tmp/powersaver-active"
# nmap patch
NMAPCMD="/usr/bin/nmap"
# vnstat path
VNSTATCMD="/usr/bin/vnstat"
# network interface
VNSTAT_IF="eth0"

# which ip range should be checked?
# this example looks in "192.168.1.10 to 192.168.1.30"
# and "192.168.178.10 to 192.168.178.30"
RANGE="192.168.0.20-100"
# how many clients are always on (other servers, routers, etc)
MINCLIENTS=0
# shutdown after how many retries?
RETRIES=3

###
# END CONFIG
###

function isAble() {
test -f $STATUSFILE || echo "COUNT=$RETRIES" > $STATUSFILE
test -f $POWERFILE || echo "" > $POWERFILE
if [ -w $POWERFILE ]; then
        return 0
else
        return 1
fi
}

function getTraffic() {
VNST=`"$VNSTATCMD" -tr -i "$VNSTAT_IF" | tr -s '[:blank:]' '\t'`
TX=`echo "$VNST" | grep "tx"`
RX=`echo "$VNST" | grep "rx"`
NTX=`echo "$TX" | cut -f 3 | tr '.' '\t' | cut -f 1`
NRX=`echo "$RX" | cut -f 3 | tr '.' '\t' | cut -f 1`
TX_UNIT=`echo "$TX" | cut -f 4`
RX_UNIT=`echo "$RX" | cut -f 4`
if [ "$RX_UNIT" == "kbit/s" ] &&
   [ "$NRX" == "0" ]; then
        return 1
else
        return 0
fi
}

case "$1" in
check)
if [ "`whoami`" != "root" ]; then
        echo "Only root can do this!"
        exit 1
fi
test -f "$POWERFILE" || (touch "$POWERFILE"; chmod 664 "$POWERFILE"; chown root:staff "$POWERFILE")
test -f "$STATUSFILE" || (touch "$STATUSFILE"; chmod 644 "$STATUSFILE"; chown root:staff "$STATUSFILE")
test `users | wc -w` -le 0 || exit 0
test "`cat $POWERFILE`" = "false" && exit 0
NUMCLIENTS=`$NMAPCMD -sP $RANGE -oG --open | grep "^Host" | wc -l`
if [ $NUMCLIENTS -le $MINCLIENTS ]; then
        if [ ! -f "$STATUSFILE" ]; then
                echo "COUNT=$RETRIES" > $STATUSFILE
        fi
                . $STATUSFILE
        if [ $COUNT -le $MINCLIENTS ] &&
           [ `users|wc -w` -le 0 ]; then
                getTraffic
                if [ $? -eq 1 ]; then
                        echo "Shutdown..."
                        echo "COUNT=$RETRIES" > $STATUSFILE
                        shutdown -h now;
                fi
        else
                let COUNT=$COUNT-1
                echo "COUNT=$COUNT" > $STATUSFILE
        fi;
        else
                echo "COUNT=$RETRIES" > $STATUSFILE
fi
;;
on)
        isAble
        if [ $? -eq 0 ]; then
                echo "" > $POWERFILE
        else
                echo "Ihnen fehlen die Rechte."
        fi
;;
off)
        isAble
        if [ $? -eq 0 ]; then
                echo "false" > $POWERFILE
        else
                echo "Ihnen fehlen die Rechte."
        fi
;;
status)
        echo -ne "Status\t: "
        if [ -r "$POWERFILE" ] &&
           [ "`cat "$POWERFILE"`" == "false" ]; then
                echo "Deaktiviert"
        else
                echo "Aktiv"
        fi
        test -r "$STATUSFILE" && (. $STATUSFILE; echo -e "WDH.\t: $COUNT")
;;
        *) echo "Usage: powersaver.sh [status|on|off]"
;;
esac

return 0

