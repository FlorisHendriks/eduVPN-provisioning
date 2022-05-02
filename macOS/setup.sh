#!/bin/bash

while getopts p:s: flag
do
        case "${flag}" in
                p) profile=${OPTARG};;
                s) vpnserver=${OPTARG};;
        esac
done

if [ -z $profile ] || [ -z $vpnserver ] 
then
	echo "ERROR: -p and -s are mandatory arguments. See usage: https://github.com/florishendriks98/eduvpn-provisioning";
	exit 1;
fi

# Create a wireguard directory only accessible by the administrator
mkdir -m 600 /etc/wireguard/

# Move the startVPN.sh to the wireguard directory
mv startVPN.sh /etc/wireguard/startVPN.sh

echo "<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>StandardOutPath</key>
        <string>/var/logs/startVPNoutput.log</string>
        <key>StandardErrorPath</key>
        <string>/var/logs/startVPNerror.log</string>
        <key>Label</key>
        <string>wireguard</string>
	<key>ProgramArguments</key>
	<array>
	<string>/etc/wireguard/startVPN.sh</string>
	<string>-p</string> 
	<string>$profile</string>
	<string>-s</string> 
	<string>$vpnserver</string>
	</array>
        <key>RunAtLoad</key>
        <true/>
        <key>AbandonProcessGroup</key>
        <true/>
        <key>StartCalendarInterval</key>
        <dict>
                <key>Hour</key>
                <integer>00</integer>
                <key>Minute</key>
                <integer>03</integer>
        </dict>
        <key>EnvironmentVariables</key>
        <dict>
                <key>PATH</key>
                <string>/usr/local/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        </dict>
</dict>
</plist>" > /Library/LaunchDaemons/wireguard.plist

# Change the permissions of the wireguard launch daemon
chown root:wheel /Library/LaunchDaemons/wireguard.plist

# Load and execute the LaunchDaemon
launchctl load /Library/LaunchDaemons/wireguard.plist
