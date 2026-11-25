#!/bin/sh
set -e
SCRIPT=/usr/local/bin/udhcpc-wlan0.script
mkdir -p /usr/local/bin
cat > "$SCRIPT" <<'EOS'
#!/bin/sh
case "$1" in
	deconfig)
		ip addr flush dev "$IFACE"
		;;
	bound|renew)
		PREFIX=24
		case "$mask" in
			255.255.0.0) PREFIX=16 ;;
			255.0.0.0) PREFIX=8 ;;
		esac
		ip addr replace "$ip/$PREFIX" dev "$IFACE" broadcast "$broadcast"
		ip route replace default via "$router" dev "$IFACE" metric 50
		# DNS: 交给 systemd-resolved，勿改 /etc/resolv.conf
		;;
esac
exit 0
EOS
chmod +x "$SCRIPT"
pkill -f "udhcpc -i wlan0" 2>/dev/null || true
sleep 1
nohup busybox udhcpc -i wlan0 -s "$SCRIPT" -f -t 10 -T 3 >/var/log/udhcpc-wlan0.log 2>&1 &
sleep 8
echo "=== addr ==="
ip addr show wlan0 | grep -E "inet "
echo "=== route ==="
ip route
echo "=== gw ping ==="
ping -c 2 -W 3 192.168.0.1 2>&1 | tail -2
echo "=== inet ping ==="
ping -c 2 -W 3 223.5.5.5 2>&1 | tail -2
