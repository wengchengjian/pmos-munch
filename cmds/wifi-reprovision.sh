#!/bin/sh
set -e
mkdir -p /etc/wpa_supplicant /run/wpa_supplicant
cat > /etc/wpa_supplicant/wpa_supplicant-wlan0.conf <<'EOC'
country=CN
ctrl_interface=DIR=/run/wpa_supplicant GROUP=netdev
update_config=1

network={
	ssid="CHANGE_ME_SSID"
	psk="CHANGE_ME_WIFI_PSK"
	key_mgmt=WPA-PSK
}
EOC
chmod 600 /etc/wpa_supplicant/wpa_supplicant-wlan0.conf

cat > /usr/local/bin/udhcpc-wlan0.script <<'EOS'
#!/bin/sh
IF="${interface:-$IFACE}"
case "$1" in
	deconfig)
		ip addr flush dev "$IF" 2>/dev/null
		;;
	bound|renew)
		PREFIX=24
		case "$mask" in
			255.255.0.0) PREFIX=16 ;;
			255.0.0.0) PREFIX=8 ;;
		esac
		ip addr flush dev "$IF" 2>/dev/null
		ip addr add "$ip/$PREFIX" dev "$IF" 2>/dev/null
		ip route del default 2>/dev/null
		ip route add default via "$router" dev "$IF" 2>/dev/null
		if [ -n "$dns" ]; then
			: > /etc/resolv.conf 2>/dev/null
			for d in $dns; do echo "nameserver $d" >> /etc/resolv.conf; done
		fi
		;;
esac
exit 0
EOS
chmod +x /usr/local/bin/udhcpc-wlan0.script

cat > /etc/systemd/system/wpa_supplicant-wlan0.service <<'EOS'
[Unit]
Description=WPA supplicant on wlan0
After=sys-subsystem-net-devices-wlan0.device
[Service]
Type=simple
Environment=LD_LIBRARY_PATH=/usr/local/wifi/lib
ExecStart=/usr/local/wifi/bin/wpa_supplicant -Dnl80211 -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
Restart=always
RestartSec=2
[Install]
WantedBy=multi-user.target
EOS

cat > /etc/systemd/system/wlan0-dhcp.service <<'EOS'
[Unit]
Description=DHCP client on wlan0 (busybox udhcpc)
After=wpa_supplicant-wlan0.service
Wants=wpa_supplicant-wlan0.service
[Service]
Type=simple
ExecStart=/usr/sbin/udhcpc -i wlan0 -s /usr/local/bin/udhcpc-wlan0.script -f -t 10 -T 3
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
EOS

systemctl daemon-reload
systemctl enable wpa_supplicant-wlan0.service wlan0-dhcp.service
systemctl restart wpa_supplicant-wlan0.service
sleep 8
LD_LIBRARY_PATH=/usr/local/wifi/lib /usr/local/wifi/bin/iw dev wlan0 link 2>&1 | head -12
systemctl restart wlan0-dhcp.service
sleep 10
echo "=== addr ==="
ip addr show wlan0 | grep -E "inet |state"
echo "=== route ==="
ip route
echo "=== resolv ==="
cat /etc/resolv.conf 2>/dev/null | head -3
echo "=== gw ping ==="
ping -c 2 -W 3 192.168.0.1 2>&1 | tail -2
