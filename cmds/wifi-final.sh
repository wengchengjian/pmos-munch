#!/bin/sh
SCRIPT=/usr/local/bin/udhcpc-wlan0.script
cat > "$SCRIPT" <<'EOS'
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
		# DNS: 交给 systemd-resolved，勿改 /etc/resolv.conf
		;;
esac
exit 0
EOS
chmod +x "$SCRIPT"
pkill -f "udhcpc -i wlan0" 2>/dev/null
cat > /etc/systemd/system/wlan0-dhcp.service <<'EOS'
[Unit]
Description=DHCP client on wlan0 (busybox udhcpc)
After=wpa_supplicant@wlan0.service
Requires=wpa_supplicant@wlan0.service
[Service]
Type=simple
ExecStart=/usr/sbin/busybox udhcpc -i wlan0 -s /usr/local/bin/udhcpc-wlan0.script -f -t 10 -T 3
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
EOS
systemctl daemon-reload
systemctl enable --now wlan0-dhcp.service
sleep 10
echo "=== addr ==="
ip addr show wlan0 | grep "inet "
echo "=== route ==="
ip route
echo "=== resolv ==="
cat /etc/resolv.conf 2>/dev/null | head -3
echo "=== gw ping ==="
ping -c 2 -W 3 192.168.0.1 2>&1 | tail -2
echo "=== internet ping ==="
ping -c 3 -W 3 223.5.5.5 2>&1 | tail -3
echo "=== dns test ==="
nslookup mirrors.aliyun.com 2>&1 | head -6
