#!/bin/sh
echo "== net =="
ping -c 1 -W 3 223.5.5.5 2>&1 | tail -2
echo "== dns =="
nslookup mirrors.aliyun.com 2>&1 | head -6
echo "== fix resolv =="
printf 'nameserver 192.168.0.1\nnameserver 223.5.5.5\nnameserver 8.8.8.8\n' > /etc/resolv.conf
cat /etc/resolv.conf
systemctl restart systemd-timesyncd 2>/dev/null || true
sleep 6
echo "== time =="
date
timedatectl 2>/dev/null | head -6
echo "== dns retry =="
nslookup mirrors.aliyun.com 2>&1 | head -6
