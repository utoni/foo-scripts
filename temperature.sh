#!/bin/sh

NAME=`basename $0`
CHIP=
WARN_TEMP=65
SHUT_TEMP=75
MAIL_USER="root"

CMD=`sensors $CHIP | grep -E '°C' | awk '{ print +$3 }'`

i=0
for temp in $CMD; do
        if [ $temp -ge $WARN_TEMP ] && [ $temp -lt $SHUT_TEMP ]; then
                echo "$0: WARNING: CPU Core heat ($temp C)" | mail -s "CPU Core WARN" $MAIL_USER
                echo "TEMP$i HEAT ($temp C)" | logger -p user.crit -t $NAME
        fi

        if [ $temp -ge $SHUT_TEMP ]; then
                echo "$0: EMERGENCY: CPU Core Meltdown! I'm going sleep .. ($temp C)" | mail -s "CPU Core EMERGENCY" $MAIL_USER
                echo "TEMP$i HEAT CRITICAL -> SHUTDOWN ($temp C)" | logger -p user.emerg -t $NAME
                /sbin/init 0
        fi

        i=`expr $i + 1`
done

