#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.100
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o ServerAliveInterval=10"
$SSH "$H" 'cat > /tmp/udhcpc-wlan0.script' < /mnt/f/project/pmos-munch/tools/udhcpc-wlan0.script || exit 1
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
install -m 755 /tmp/udhcpc-wlan0.script /usr/local/bin/udhcpc-wlan0.script
echo == restart dhcp ==
systemctl restart wlan0-dhcp.service
sleep 12
systemctl is-active wlan0-dhcp.service
echo == ip ==
ip -4 addr show wlan0 | grep inet
echo == resolv ==
ls -l /etc/resolv.conf
cat /etc/resolv.conf | grep -v \"^#\" | head -5
echo == dns ==
resolvectl status 2>/dev/null | head -12
getent hosts registry.npmmirror.com | head -1
getent hosts mirrors.aliyun.com | head -1
echo == net ==
ping -c 2 -W 3 223.5.5.5 2>&1 | tail -2
curl -s -m 8 -o /dev/null -w \"npmmirror=%{http_code}\n\" https://registry.npmmirror.com/
"' 2>&1 | grep -a -v "Permanently added"