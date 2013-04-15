#!/bin/sh

# CONFIG FILE
[ -z "$CONF" ] && CONF=/etc/iptables.conf
# IPTABKES BINARY
[ -z "$IPT" ] && export IPT=/usr/sbin/iptables

[ "`whoami`" != 'root' ] && echo "$0: must be run as root" && exit 2
[ -x $IPT ] || exit 0

[ $# -ge 1 ] && export MODE="$1"
[ $# -ge 2 ] && export IFACE="$2"

[ -r ${CONF} ] && . ${CONF}


flush_all() {
    # flush/delete chains
    $IPT -F
    $IPT -t nat -F
    $IPT -X
    $IPT --delete-chain
    $IPT --table nat --delete-chain
}

ipt() {
    # internal iptables call
    rule="$*"
    [ $# -eq 1 ] && rule="$1"

    $IPT -D $rule 2>/dev/null
    $IPT -A $rule 2>/dev/null
}

default_pol() {
    # default policies
    $IPT -P INPUT DROP
    $IPT -P OUTPUT ACCEPT
    $IPT -P FORWARD DROP
}

check_ip() {
    local ip
    ip="$1"
    echo "$ip" | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'
    return $?
}

get_conf_opt() {
    local var arg ret
    var="$1"
    arg="$2"

    eval "ret=\${${var}_${arg}}"
    [ -z "$ret" ] && return 1
    echo "$ret"
    return 0
}

get_conf_opts() {
    local i var arg ret
    var="$1"
    arg="$2"
    i=0

    while `true`; do
        ret="`get_conf_opt ${var} ${arg}_${i}`"
        [ $? -eq 0 ] || break
        echo "$ret"

        i=`expr $i + 1`
    done
}

_ipforward() {
    [ -f /proc/sys/net/ipv4/conf/$1/forwarding ] && \
         echo 1 > /proc/sys/net/ipv4/conf/$1/forwarding
}

do_ipforward() {
    local if ret
    [ -z "$INTERFACES" ] && return 1
    if [ -z "$1" ]; then
       _ipforward "$1"
       return 0
   fi

   for if in $INTERFACES; do
       ret=`get_conf_opt $if KERN_FORWARD`
       [ $? -eq 0 ] && _ipforward "$if"
   done
}

start_if() {
    [ -z "$INTERFACES" ] && return 1
    iface="$1"

    ipt "INPUT -i lo -j ACCEPT"
    ipt "INPUT -p icmp -j ACCEPT"

    for if in $INTERFACES; do
        [ -f /var/lock/$if.ipt.lock -a "$iface" != "$if" ] && continue

        $IPT -N $if 2>/dev/null
        $IPT -F $if
        ipt "INPUT -i $if -j $if"
        ipt "OUTPUT -o $if -j $if"

        do_ipforward $if
        ret=`get_conf_opt $if FORWARD`
        [ $? -eq 0 ] && ipt "FORWARD -i $if -j ACCEPT"

        ret=`get_conf_opt $if POSTROUTING`
        if [ $? -eq 0 ]; then
           $IPT -t nat -D POSTROUTING -o $if -j MASQUERADE 2>/dev/null
           $IPT -t nat -A POSTROUTING -o $if -j MASQUERADE
        fi

        ret=`get_conf_opt $if TCP_PORTS`
        if [ $? -eq 0 ]; then
           for port in $ret; do
              ipt "$if -p tcp --dport $port -i $if -j ACCEPT"
           done
        fi

        ret=`get_conf_opt $if UDP_PORTS`
        if [ $? -eq 0 ]; then
           for port in $ret; do
              ipt "$if -p udp --dport $port -i $if -j ACCEPT"
           done
        fi

        ipt "INPUT -j REJECT --reject-with icmp-host-prohibit"

        touch /var/lock/$IFACE.ipt.lock 2>/dev/null
        [ "$if" == "$iface" ] && break
    done

    return 0
}

print_usage() {
cat << EOF
$0: start [if]
$0: stop [if]
$0: reload|restart [if]
$0: flush
$0: ipforward
EOF

return 0
}



case "$MODE" in

        start)
                [ -z "$MODE" -o -z "$IFACE" ] && print_usage && exit 1
                start_if "$IFACE"
                default_pol
        ;;

        stop)
                [ -z "$MODE" -o -z "$IFACE" ] && print_usage && exit 1
                $IPT -F "$IFACE" 2>/dev/null
                rm -f /var/lock/$IFACE.ipt.lock 2>/dev/null
        ;;

        reload|restart)
                $0 stop $IFACE
                $0 start $IFACE
        ;;

        flush)
                flush_all
                echo 0 > /proc/sys/net/ipv4/conf/all/forwarding
                # SSH fallback (dont lock yourself out!)
                $IPT -P INPUT ACCEPT
        ;;

        ipforward)
                do_ipforward
                return 0
        ;;

        *)
                print_usage
        ;;

esac
