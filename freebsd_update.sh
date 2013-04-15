#!/bin/sh -f

#####################################################
# DESC:    Freebsd update script (host+jails)       #
#          using portupgrade,portsnap and portaudit #
# VERSION: 0.1a                                     #
# AUTHOR:  Toni U.                                  #
# EMAIL:   matzeton@googlemail.com                  #
#####################################################


portupg="/usr/local/sbin/portupgrade"
portsnp="/usr/sbin/portsnap"
portaud="/usr/local/sbin/portaudit"
fupdate="/usr/sbin/freebsd-update"
logdir="/root"
dt=`date +%d%m_%H%M`

if [ -r /etc/defaults/periodic.conf ]; then
            . /etc/defaults/periodic.conf
                source_periodic_confs
fi

if [ "$1" = "check" ]; then
                checkonly=1
        else
                checkonly=0
fi

. /etc/rc.conf

        rc=0
        case "${daily_status_security_jailportaudit_enable:-YES}" in
                [Nn][Oo])
        ;;
        *)
             test -x "$fupdate" || { echo "\tmissing $fupdate"; exit 1; }
             $fupdate fetch
             $fupdate install
             test -x "$portsnp" || { echo "\tmissing $portsnp"; exit 1; }
             $portsnp fetch update
             test -x "$portaud" || { echo "\tmissing $portaud"; exit 1; }
             $portaud -F
             echo

             tmpdir=`mktemp -d /tmp/jailportaudit.XXXXXXXX`
             cd $tmpdir

             echo "Checking pkg's in /"
             rm $logdir/rupd_error.log 2>/dev/null
             ls -1 /var/db/pkg > $tmpdir/root.paf
             APKG=`$portaud -f $tmpdir/root.paf | grep "Affected package:" | cut -d ' ' -f 3`
             for pkg in `echo "$APKG"`; do
                     echo "* UPDATING $pkg ...";
                     $portupg -fur $pkg 2>> "/root/rupd_error.log"
             done

             for jail in $jail_list; do
                     rm $logdir/jupd_$jail_error.log 2>/dev/null
                     eval jaildir=\"\$jail_${jail}_rootdir\"
                     echo ""

                     if [ ! -d $jaildir/usr/ports ]; then
                        mkdir $jaildir/usr/ports;
                        echo "* Creating $jaildir/usr/ports";
                     else
                        echo "* $jaildir/usr/ports exists! fine."
                     fi
                     echo "* mounting /usr/ports to $jaildir/usr/ports"
                     mount_nullfs /usr/ports $jaildir/usr/ports
                     echo "* checking for portupgrade"
                     test -x "$jaildir/$portupg" || { echo "missing $jaildir/$portupg"; jexec $(jls | grep "$jail" | tr -s ' ' ' ' | cut -f 2 -d ' ') /bin/sh -c "cd /usr/ports/ports-mgmt/portupgrade; make install;"; }
                     echo "* checking for packages with security vulnerabilities in jail \"$jail\":"
                        echo -e "\t-> $jaildir\n"
                        ls -1 $jaildir/var/db/pkg > $tmpdir/$jail.paf
                        APKG=`$portaud -f $tmpdir/$jail.paf | grep "Affected package:" | cut -d ' ' -f 3`
                        if [ $checkonly -eq 0 ]; then
                                for pkg in `echo "$APKG"`; do echo "* UPDATING $pkg ..."; jexec $(jls | grep "$jail" | tr -s ' ' ' ' | cut -f 2 -d ' ') /bin/sh -c "$portupg -fur $pkg" 2>> "$logdir/jupd_$jail_error.log"; done
                        fi
                        rm $tmpdir/$jail.paf
                    umount $jaildir/usr/ports
             done
        ;;
        esac
exit "$rc"
