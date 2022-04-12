#!/bin/bash

# Move the no.corporate.wireguard.plist file to /Library/LaunchDaemons/
mv wireguard.plist /Library/LaunchDaemons/

# Create a wireguard directory only accessible by the administrator
mkdir -m 600 /etc/wireguard/

# Move the startVPN.sh to the wireguard directory
mv startVPN.sh /etc/wireguard/

# Load and execute the LaunchDaemon
launchctl load /Library/LaunchDaemons/wireguard.plist
