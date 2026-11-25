#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.100
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"
$SSH "$H" 'cat > /tmp/redis.service' < /mnt/f/project/pmos-munch/units/redis.service || exit 1
$SSH "$H" 'cat > /tmp/90-docker.conf' < /mnt/f/project/pmos-munch/units/90-docker.conf || exit 1
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
install -m 644 /tmp/redis.service /etc/systemd/system/redis.service
install -m 644 /tmp/90-docker.conf /etc/sysctl.d/90-docker.conf
sysctl --system >/dev/null 2>&1; sysctl vm.overcommit_memory
systemctl daemon-reload
systemctl reset-failed redis.service 2>/dev/null || true
systemctl restart redis.service
sleep 2
systemctl is-active redis.service
ls -ld /run/redis
redis-cli ping
systemctl status redis.service --no-pager -l 2>&1 | head -12
"' 2>&1 | grep -a -v "Permanently added"