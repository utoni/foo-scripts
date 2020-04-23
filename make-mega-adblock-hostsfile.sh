#!/bin/bash
# Modified Pi-hole script to generate a generic hosts file
# for use with dnsmasq's addn-hosts configuration
# original : https://github.com/jacobsalmela/pi-hole/blob/master/gravity-adv.sh
# now-from : https://gist.githubusercontent.com/chrisvella/5f3a18f1e442153cd685/raw/348311d6e8b35ccee3011d0164b7dbc0488ebcbd/make-mega-adblock-hostsfile.sh

# Address to send ads to. This could possibily be removed, but may be useful for debugging purposes?
destinationIP="0.0.0.0"

outlist='./final_blocklist.txt'
tempoutlist="$outlist.tmp"

echo "Getting yoyo ad list..."
curl -s -d mimetype=plaintext -d hostformat=unixhosts http://pgl.yoyo.org/adservers/serverlist.php? | sort > $tempoutlist
echo "Getting winhelp2002 ad list..."
curl -s http://winhelp2002.mvps.org/hosts.txt | grep -v "#" | grep -v "127.0.0.1" | sed '/^$/d' | sed 's/\ /\\ /g' | awk '{print $2}' | sort >> $tempoutlist
echo "Getting adaway ad list..."
curl -s https://adaway.org/hosts.txt | grep -v "#" | grep -v "::1" | sed '/^$/d' | sed 's/\ /\\ /g' | awk '{print $2}' | grep -v '^\\' | grep -v '\\$' | sort >> $tempoutlist
echo "Getting hosts-file ad list..."
curl -s http://hosts-file.net/.%5Cad_servers.txt | grep -v "#" | grep -v "::1" | sed '/^$/d' | sed 's/\ /\\ /g' | awk '{print $2}' | grep -v '^\\' | grep -v '\\$' | sort >> $tempoutlist
echo "Getting malwaredomainlist ad list..."
curl -s http://www.malwaredomainlist.com/hostslist/hosts.txt | grep -v "#" | sed '/^$/d' | sed 's/\ /\\ /g' | awk '{print $3}' | grep -v '^\\' | grep -v '\\$' | sort >> $tempoutlist
echo "Getting adblock.gjtech ad list..."
curl -s http://adblock.gjtech.net/?format=unix-hosts | grep -v "#" | sed '/^$/d' | sed 's/\ /\\ /g' | awk '{print $2}' | grep -v '^\\' | grep -v '\\$' | sort >> $tempoutlist
echo "Getting someone who cares ad list..."
curl -s http://someonewhocares.org/hosts/hosts | grep -v "#" | sed '/^$/d' | sed 's/\ /\\ /g' | grep -v '^\\' | grep -v '\\$' | awk '{print $2}' | grep -v '^\\' | grep -v '\\$' | sort >> $tempoutlist
echo "Getting Mother of All Ad Blocks list..."
curl -A 'Mozilla/5.0 (X11; Linux x86_64; rv:30.0) Gecko/20100101 Firefox/30.0' -e http://forum.xda-developers.com/ http://adblock.mahakala.is/ | grep -v "#" | awk '{print $2}' | sort >> $tempoutlist

# Remove entries from the whitelist file if it exists at the root of the current user's home folder
echo "Removing duplicates and formatting the list of domains..."
# Removed the uniq command, using sort -u. Removes the dependency on uniq, which is not available on the router by default or via opkg.
# Added a rough way to exclude domains from the list. If you have a number of domains to whitelist, a better solution could be explored.
	cat $tempoutlist | sed $'s/\r$//' | sed '/thisisiafakedomain123\.com/d;/www\.anotherfakedomain123\.com/d' | sort -u | sed '/^$/d' | awk -v "IP=$destinationIP" '{sub(/\r$/,""); print IP" "$0}' > $outlist



# Removes the temporary list.
rm $tempoutlist

# Count how many domains/whitelists were added so it can be displayed to the user
numberOfAdsBlocked=$(cat $outlist | wc -l | sed 's/^[ \t]*//')
echo "$numberOfAdsBlocked ad domains blocked."




# Find a location to save the script. Make sure the file will survive reboot. One option is to mount a usb.
# This gist provides instructions on using a usb for optware on tomato firware (which is really useful on its own): https://gist.github.com/dferg/833aade513965d78b43d

# Now scp this file to a desired location on your router. Its also possible to wget the raw version of this gist.
# scp ./adblock.hosts user@192.168.1.1:/mnt/sda1/dnsmasq/

# Give the script permissions to execute:
# chmod +x make-mega-adblock-hostsfile.sh

# Add the hosts file and extra configuration to tomato's dnsmasq config via Advanced -> DHCP/DNS -> DnsMasq Custom configuration
# addn-hosts=/opt/dnsmasq/final_blocklist.txt
# Never forward plain names (without a dot or domain part)
# domain-needed
# Never forward addresses in the non-routed address spaces.
# bogus-priv

# For debugging purposes, log each DNS query as it passes through dnsmasq. Remove this once you have confirmed it is working.
# log-queries
# log-facility=/opt/dnsmasq/adblocking.log
# This allows it to continue functioning without being blocked by syslog, and allows syslog to use dnsmasq for DNS queries without risking deadlock
# log-async

# Go to Administration -> Scheduler -> Custom (Sets the script to update itself. Choose your own schedule.)
# sh /opt/dnsmasq/make-mega-adblock-hostsfile.sh

# Add another custom command:
# service dnsmasq restart
# ~OR~
# Have the router reboot sometime after the script has been downloaded.
