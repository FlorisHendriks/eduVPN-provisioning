#!/bin/bash

# Move the no.corporate.wireguard.plist file to /Library/LaunchDaemons/
mv wireguard.plist /Library/LaunchDaemons/

# Create a wireguard directory only accessible by the administrator
mkdir -m 600 /etc/wireguard/

# Move the startVPN.sh to the wireguard directory
mv startVPN.sh /etc/wireguard/

# Install the HomeBrew package manager
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Wireguard-tools
brew install wireguard-tools

brew install grep

brew install date

# Load and execute the LaunchDaemon
launchctl load /Library/LaunchDaemons/wireguard.plist