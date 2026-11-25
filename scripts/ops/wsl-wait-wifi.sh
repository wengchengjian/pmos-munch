#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=4"
for i in $(seq 1 40); do
	for ip in 192.168.0.100 192.168.0.103; do
		if $SSH user@$ip 'uname -r' >/dev/null 2>&1; then
			echo "UP at $ip after $((i*4))s"
			$SSH user@$ip 'uname -a; ip link show wlan0 | grep ether; ip addr show wlan0 | grep inet; systemctl is-active wpa_supplicant-wlan0.service wlan0-dhcp.service' 2>&1 | grep -v "Permanently added"
			exit 0
		fi
	done
	sleep 4
done
echo "WIFI_NOT_UP"
exit 1
