#!/bin/sh

# flush chains
iptables -F
iptables -t nat -F
iptables -X

# default policies
iptables -P INPUT DROP
iptables -P OUTPUT ACCEPT
iptables -P FORWARD DROP

export LAN="eth0"
export WAN_IF="eth1"
export WAN="ppp0"
export RANGE="192.168.0.0/24"
export SNAT_MAP="65000-65535"

export HOSTS="192.168.0.1/32 192.168.0.0/24"
export PORTS="udp;domain;${LAN};2 tcp;domain;${LAN};2 udp;dns-query;${WAN};0 udp;bootps;${LAN};0 udp;netbios-ns;${LAN};0 udp;netbios-dgm;${LAN};0 tcp;microsoft-ds;${LAN};2 tcp;netbios-ssn;${LAN};2  tcp;http;${LAN};1 tcp;https;${LAN};1 tcp;vnc;${LAN};2"
export FORWARD_IF="venet0;192.168.0.4 venet0;192.168.0.5 venet0;192.168.0.6 venet0;192.168.0.7 venet0;192.168.0.8 venet0;192.168.0.9 venet0;192.168.0.10"
export NO_FILTER_IF="lo ${WAN_IF} venet0"

echo "$0: DEFAULT RULES"
for if in `echo $NO_FILTER_IF`; do
  echo "$0: NO FILTER ON DEV $if"
  iptables -I INPUT 1 -i $if -j ACCEPT
  iptables -I OUTPUT 1 -o $if -j ACCEPT
done
iptables -I INPUT -p icmp -m limit --limit 4/s -j ACCEPT
iptables -A FORWARD -s 0.0.0.0/0.0.0.0 -d 0.0.0.0/0.0.0.0 -m state --state INVALID -j DROP
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
# TCP syn flood protection
iptables -N syn-flood
iptables -A INPUT -p tcp -j syn-flood
iptables -A syn-flood -m limit --limit 100/second --limit-burst 150 -j RETURN
iptables -A syn-flood -j LOG --log-prefix "SYN flood: "
iptables -A syn-flood -j REJECT
# SSH specific (ANTI BRUTE FORCE)
iptables -N ssh
iptables -A INPUT -p tcp --dport 22 -j ssh
iptables -A ssh -p tcp --dport 22 -m state --state NEW -m recent --set --name SSH -j ACCEPT
iptables -A ssh -p tcp --dport 22 -m recent --update --seconds 60 --hitcount 4 --rttl  --name SSH -j LOG --log-prefix "SSH_brute_force "
iptables -A ssh -p tcp --dport 22 -m recent --update --seconds 60  --hitcount 4 --rttl --name SSH -j REJECT
# WWW (WAN)
iptables -t nat -A PREROUTING -p tcp -i ${WAN} --dport 80 -j DNAT --to 192.168.0.6

echo "$0: PORT RULES"
for port in `echo $PORTS`; do
  echo $port | grep -e '.*;.*;.*;.*' >&2 >/dev/null
  ret=$?
  if [ $ret -ne 0 ]; then
    echo "$0: PORT FORMAT UNKNOWN"
    exit 1
  fi

  proto=`echo $port | cut -d ';' -f 1`
  dport=`echo $port | cut -d ';' -f 2`
  if=`echo $port | cut -d ';' -f 3`
  hosti=`echo $port | cut -d ';' -f 4`

  echo -n "$0: PORT RULE( $proto/$dport @ $if ) "
  if [ $hosti -le 0 ]; then
    host=""
    iptables -A INPUT -p $proto --dport $dport -i $if -j ACCEPT
    ret=$?
  else
    host=`echo $HOSTS | cut -d ' ' -f $hosti`
    echo -n "-> ( $host ) "
    iptables -A INPUT -p $proto -s $host --dport $dport -i $if -j ACCEPT
  fi

  ret=$?
  if [ $ret -ne 0 ]; then
    echo " FAIL."
  else
    echo "OK."
  fi
done

# DEFAULT REJECT
iptables -A INPUT -j REJECT --reject-with icmp-host-prohibit

echo "$0: FORWARD RULES"
iptables -A FORWARD -i ${LAN} -s $RANGE -j ACCEPT
iptables -A FORWARD -i ${WAN} -d $RANGE -j ACCEPT
for fif in `echo $FORWARD_IF`; do
  echo $port | grep -e '.*;.*' >&2 >/dev/null
  ret=$?
  if [ $ret -ne 0 ]; then
    echo "$0: WRONG FORWARD FORMAT !!!"
    exit 1
  fi

  if=`echo $fif | cut -d ';' -f 1`
  ip=`echo $fif | cut -d ';' -f 2`

  echo "$0: FORWARD $if @ $ip"
  iptables -A FORWARD -i $if -s $ip -j ACCEPT
done

echo "$0: NAT RULES"
iptables -t nat -A POSTROUTING -p tcp -o ${WAN} -j MASQUERADE --to-ports ${SNAT_MAP}
iptables -t nat -A POSTROUTING -p udp -o ${WAN} -j MASQUERADE --to-ports ${SNAT_MAP}
iptables -t nat -A POSTROUTING -p icmp -o ${WAN} -j MASQUERADE

echo "$0: IP FORWARDING"
echo 1 > /proc/sys/net/ipv4/ip_forward
for f in /proc/sys/net/ipv4/conf/*/rp_filter ; do echo 1 > $f ; done

echo -n "$0: SAVE RULES FILE to /etc/iptables.rules? (Y/n) "
read answ

if [ "$answ" = "Y" ]; then
  iptables-save > /etc/iptables.rules
  chmod 0600 /etc/iptables.rules
fi

