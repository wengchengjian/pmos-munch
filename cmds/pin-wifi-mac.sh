#!/bin/sh
set -e
F=/etc/systemd/system/wpa_supplicant-wlan0.service
if ! grep -q "ip link set wlan0 address" "$F"; then
	sed -i '/^\[Service\]/a ExecStartPre=/bin/sh -c "ip link set wlan0 down; ip link set wlan0 address 02:00:7b:15:30:a6; ip link set wlan0 up"' "$F"
fi
cat "$F"
systemctl daemon-reload
echo "=== current mac ==="
ip link show wlan0 | grep ether
