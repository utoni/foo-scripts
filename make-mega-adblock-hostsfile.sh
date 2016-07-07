#!/bin/bash
# Modified Pi-hole script to generate a generic hosts file
# for use with dnsmasq's addn-hosts configuration
# original : https://github.com/jacobsalmela/pi-hole/blob/master/gravity-adv.sh

# The Pi-hole now blocks over 120,000 ad domains
# Address to send ads to (the RPi)
piholeIP="208.69.33.152"

outlist='./final_blocklist.txt'
tempoutlist="$outlist.tmp"

echo "Getting yoyo ad list..." # Approximately 2452 domains at the time of writing
curl -s -d mimetype=plaintext -d hostformat=unixhosts http://pgl.yoyo.org/adservers/serverlist.php? | sort > $tempoutlist
echo "Getting winhelp2002 ad list..." # 12985 domains
curl -s http://winhelp2002.mvps.org/hosts.txt | grep -v "#" | grep -v "127.0.0.1" | sed '/^$/d' | sed 's/\ /\\ /g' | awk '{print $2}' | sort >> $tempoutlist
echo "Getting adaway ad list..." # 445 domains
curl -s https://adaway.org/hosts.txt | grep -v "#" | grep -v "::1" | sed '/^$/d' | sed 's/\ /\\ /g' | awk '{print $2}' | grep -v '^\\' | grep -v '\\$' | sort >> $tempoutlist
echo "Getting hosts-file ad list..." # 28050 domains
curl -s http://hosts-file.net/.%5Cad_servers.txt | grep -v "#" | grep -v "::1" | sed '/^$/d' | sed 's/\ /\\ /g' | awk '{print $2}' | grep -v '^\\' | grep -v '\\$' | sort >> $tempoutlist
echo "Getting malwaredomainlist ad list..." # 1352 domains
curl -s http://www.malwaredomainlist.com/hostslist/hosts.txt | grep -v "#" | sed '/^$/d' | sed 's/\ /\\ /g' | awk '{print $3}' | grep -v '^\\' | grep -v '\\$' | sort >> $tempoutlist
echo "Getting adblock.gjtech ad list..." # 696 domains
curl -s http://adblock.gjtech.net/?format=unix-hosts | grep -v "#" | sed '/^$/d' | sed 's/\ /\\ /g' | awk '{print $2}' | grep -v '^\\' | grep -v '\\$' | sort >> $tempoutlist
echo "Getting someone who cares ad list..." # 10600
curl -s http://someonewhocares.org/hosts/hosts | grep -v "#" | sed '/^$/d' | sed 's/\ /\\ /g' | grep -v '^\\' | grep -v '\\$' | awk '{print $2}' | grep -v '^\\' | grep -v '\\$' | sort >> $tempoutlist
#echo "Getting Mother of All Ad Blocks list..." # 102168 domains!! Thanks Kac
#curl -A 'Mozilla/5.0 (X11; Linux x86_64; rv:30.0) Gecko/20100101 Firefox/30.0' -e http://forum.xda-developers.com/ http://adblock.mahakala.is/ | grep -v "#" | awk '{print $2}' | sort >> $tempoutlist

# Sort the aggregated results and remove any duplicates
# Remove entries from the whitelist file if it exists at the root of the current user's home folder
echo "Removing duplicates and formatting the list of domains..."
	cat $tempoutlist | sed $'s/\r$//' | sort | uniq | sed '/^$/d' | awk -v "IP=$piholeIP" '{sub(/\r$/,""); print IP" "$0}' > $outlist

# Count how many domains/whitelists were added so it can be displayed to the user
numberOfAdsBlocked=$(cat $outlist | wc -l | sed 's/^[ \t]*//')
echo "$numberOfAdsBlocked ad domains blocked."

# Now scp this file to a desired location on your router
# Add the hosts file to tomato's dnsmasq config via Advanced -> DHCP/DNS -> DnsMasq Custom configuration
# addn-hosts=/mnt/sda1/dnsmasq/adblock.hosts

# scp ./adblock.hosts user@192.168.1.1:/mnt/sda1/dnsmasq/

# SSH to Tomato and restart DNS
# ssh user@192.168.1.1
# sudo service dnsmasq restart
