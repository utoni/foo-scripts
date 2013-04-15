#!/bin/bash
#
##########################################
# DESC:    script to check host services #
#		   (originally for freebsd,      #
#		    this is the linux version)   #
# VERSION: 0.1a                          #
# AUTHOR:  Toni U.                       #
# EMAIL:   matzeton@googlemail.com       #
##########################################
#

# SYNTAX: SERVICES="[SERVICE0][:[PROCESS_COUNT0]] [SERVICE1][:[PROCESS_COUNT1]] [SERVICEn][:[PROCESS_COUNTn]]"
SERVICES="pflogd:2 /usr/sbin/cron /usr/local/libexec/slapd /usr/sbin/ppp"

function checkroot {
if [ "`whoami`" == "root" ]; then
        return 0;
else
        echo -e "${RED}You are not root. Its posible that you dont see any daemons running (security restrictions).${NC}"
        read -n 1 -p "continue? (Y/n) " a
        [ "$a" != "Y" ] && { echo; exit 1; }
        return 1;
fi
}

function checkdaemon {
SERVICE=`echo "$1" | cut -d ':' -f 1`
SERVICE_COUNT=`echo "$1" | cut -d ':' -f 2  | grep -E "^[0-9]+$"`
[ "$SERVICE_COUNT" == "" ] && SERVICE_COUNT=1

PR=$(ps ax)
PS=$(echo "$PR" | grep "$SERVICE" | awk '{print $4}')
if [ "$PS" != "" ]; then
  PC=$(echo "$PS" | wc -l | tr -d ' ')
else
  PC=0
fi

SERVICE=`basename "$SERVICE"`
if [ $PC -gt 0 ]
    then
      NET=$(netstat -46ln | grep "$SERVICE" | awk '{print $5 "/" $6}')
      SRV_CHG=1
      PSC="${CYAN}$PC${NC}"
      if [ $PC -ge $SERVICE_COUNT ]; then
        PSC="${CYAN}$PC/$SERVICE_COUNT${NC}"
      else
        PSC="${RED}$PC/$SERVICE_COUNT${NC}"
        [ $SRV_CHG -eq 1 ] && { SRV_CHG=0; ALLOK=0; SRVERR=`expr $SRVERR + 1`; }
        echo -e "$SERVICE: ${RED}WARNING(${CYAN}`echo $PJ`${RED}): PCOUNT $SERVICE_COUNT != $PC ${NC}" >&2
      fi
      echo -e "$SRVTOT\t[ ${GREEN}OK${NC} ]:$SERVICE\t\tpcount $PSC${NC}"
      [ $NOSOCK -eq 0 ] && [ "$NET" != "" ] && echo -e "\t       sock ${cyan}`echo $NET`${NC}"
      SRVOK=`expr $SRVOK + 1`
    else
      echo -e "\n  ${red}+-->${NC}  [${RED}FAIL${NC}]  $SERVICE" 1>&2
      echo -e "$SERVICE service not running!" | mail -s "$SERVICE down" root
      ALLOK=0
      SRVERR=`expr $SRVERR + 1`
    fi
}

checkroot
echo -e "${RED}*${NC} ${CYAN}Checking services ..${NC}" 1>&2
NOSOCK=0
[ "$1" == "nosock" ] && NOSOCK=1

ALLOK=1
SRVOK=0
SRVERR=0
SRVTOT=0
for srv in $SERVICES
do
        checkdaemon "$srv"
        SRVTOT=`expr $SRVTOT + 1`
done

if [ $ALLOK -eq 1 ]; then
    echo -e "\n${CYAN}*${NC} [ ${GREEN}OK${NC} ] ${GREEN}$SRVOK${NC}/${GREEN}$SRVTOT${NC} ${CYAN}SERVICES${NC}" 1>&2
    exit 0
  else
    echo -e "\n${RED}###${NC} [${RED}FAIL${NC}] ${RED}$SRVERR/$SRVTOT${CYAN} services may not be available.${NC}" 1>&2
    exit 1
fi
