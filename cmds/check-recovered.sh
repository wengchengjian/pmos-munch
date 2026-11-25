#!/bin/sh
echo "== uname =="; uname -a
echo "== ip =="; ip addr show 2>/dev/null | grep -E "^[0-9]+:|inet " | head -20
echo "== tools =="; for t in wpa_supplicant iw ip udhcpc apk ssh sshd; do printf "%s: " "$t"; command -v "$t" || echo MISSING; done
echo "== wlan =="; ip link 2>/dev/null | grep -i wlan; ls /sys/class/net
echo "== wpaconf =="; ls -la /etc/wpa_supplicant 2>/dev/null || echo none
echo "== modules =="; ls /lib/modules/ 2>/dev/null; lsmod 2>/dev/null | head -15
echo "== mounts =="; mount | grep -E "proc |sys |run |boot|loop" | head
echo "== net reach =="; ping -c 1 -W 2 172.16.42.2 2>&1 | tail -2
echo "== ports =="; ss -lntp 2>/dev/null | head -10
