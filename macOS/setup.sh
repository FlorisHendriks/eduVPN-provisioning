#!/bin/bash

# Move the no.corporate.wireguard.plist file to /Library/LaunchDaemons/
cp wireguard.plist /Library/LaunchDaemons/

# Create a wireguard directory only accessible by the administrator
mkdir -m 600 /etc/wireguard/

# Move the startVPN.sh to the wireguard directory
cp startVPN.sh /etc/wireguard/

# Change the permissions of the wireguard launch daemon
sudo chown root:wheel /Library/LaunchDaemons/wireguard.plist

# Load and execute the LaunchDaemon
launchctl load /Library/LaunchDaemons/wireguard.plist
