#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.100
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o ServerAliveInterval=10"
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
for s in containerd docker redis postgresql; do echo \"== \$s ==\"; systemctl is-active \$s; systemctl is-enabled \$s 2>/dev/null; done
echo == failed ==
systemctl --failed --no-pager
echo == redis log ==
journalctl -u redis -n 20 --no-pager 2>/dev/null | tail -20
echo == pg log ==
journalctl -u postgresql -n 20 --no-pager 2>/dev/null | tail -20
echo == docker info ==
timeout 20 docker info 2>&1 | head -25
echo == redis ping ==
timeout 10 redis-cli ping 2>&1
echo == psql ==
su -s /bin/sh postgres -c \"psql -tAc \\\"select version();\\\"\" 2>&1 | head -2
"' 2>&1 | grep -a -v "Permanently added"