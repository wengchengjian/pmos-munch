#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.100
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
echo == enabled/active ==
for s in containerd docker redis postgresql sshd panel-blank wpa_supplicant-wlan0 wlan0-dhcp systemd-resolved; do printf \"%-28s \" \$s; echo \"\$(systemctl is-enabled \$s 2>/dev/null)/\$(systemctl is-active \$s 2>/dev/null)\"; done
echo == ports ==
ss -lntp 2>/dev/null | grep -E \":(6379|5432|2375|22) \" || netstat -lntp 2>/dev/null | grep -E \":(6379|5432|2375|22) \"
echo == udhcpc script dns ==
grep -nE \"resolv|dns\" /usr/local/bin/udhcpc-wlan0.script 2>/dev/null || echo no-dns-write
echo == resolv ==
ls -l /etc/resolv.conf
resolvectl status 2>/dev/null | head -10
echo == docker summary ==
docker info 2>/dev/null | grep -E \"Server Version|Storage Driver|Cgroup Driver|Registry Mirrors|DNS Servers\" -A2 | head -15
docker images --format \"{{.Repository}}:{{.Tag}} {{.Size}}\" 2>/dev/null | head -5
echo == pg/redis ==
redis-cli ping
su -s /bin/sh postgres -c \"psql -tAc \\\"select version();\\\"\" 2>&1 | head -1
echo == space ==
df -h / | tail -1
"' 2>&1 | grep -a -v "Permanently added"