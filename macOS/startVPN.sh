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

# while we do not have an internet connection, we do not try to establish a vpn connection
while ! ping -c1 -W1 $vpnserver &> /dev/null ; do
    sleep 5
done

if [ -f '/etc/wireguard/wg0.conf' ]; then
        wg-quick up /etc/wireguard/wg0.conf
fi

if [ -f '/etc/wireguard/expiryDate.txt' ]; then
        wireguardDate=$(gdate --date=$(head /etc/wireguard/expiryDate.txt) --iso-8601)
else
        ggrep -P -o '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?([zZ]|([\+-])([01]\d|2[0-3]):?([0-5]\d)?)?' /etc/wireguard/wg0.conf > /etc/wireguard/expiryDate.txt
        wireguardDate=$(gdate --date=$(head /etc/wireguard/expiryDate.txt) --iso-8601)
fi

certificateName=$(ioreg -l | awk '/IOPlatformSerialNumber/{print $NF}')
certificateName=$(echo $certificateName | tr -d '"')

certificateDate=$(gdate --date="$(security find-certificate -c "$certificateName" -p | openssl x509 -noout -enddate | awk -F '=' '{print $NF}' )" --iso-8601)

if ! { [ -f '/etc/wireguard/wg0.conf' ] && [ "${wireguardDate}" '>' "${certificateDate}" ]; } then
        wg-quick down wg0
        config=$( CURL_SSL_BACKEND=secure-transport curl --cert "$certificateName" -d "profile_id=$profile" -H "Accept: application/x-wireguard-profile" "https://$vpnserver/vpn-user-portal/api/v3/provision")
        if [ -z "$config" ]; then
                wg-quick up /etc/wireguard/wg0.conf
        else
                > /etc/wireguard/wg0.conf
                echo "$config" | sudo tee -a /etc/wireguard/wg0.conf
                ggrep -P -o '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?([zZ]|([\+-])([01]\d|2[0-3]):?([0-5]\d)?)?' /etc/wireguard/wg0.conf > /etc/wireguard/expiryDate.txt
                wg-quick up /etc/wireguard/wg0.conf
        fi
fi
