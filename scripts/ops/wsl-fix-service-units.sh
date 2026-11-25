#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.100
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o ServerAliveInterval=10"
U=/mnt/f/project/pmos-munch/units
$SSH "$H" 'cat > /tmp/redis.service' < "$U/redis.service" || exit 1
$SSH "$H" 'cat > /tmp/postgresql.service' < "$U/postgresql.service" || exit 1
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
install -m 644 /tmp/redis.service /etc/systemd/system/redis.service
install -m 644 /tmp/postgresql.service /etc/systemd/system/postgresql.service
systemctl daemon-reload
echo == stop redis old job ==
redis-cli shutdown 2>/dev/null || true
systemctl stop redis.service 2>/dev/null || true
systemctl reset-failed redis.service 2>/dev/null || true
systemctl start redis.service; echo redis-start-rc=\$?
sleep 1
systemctl is-active redis.service
redis-cli ping 2>&1
echo == postgres ==
systemctl reset-failed postgresql.service 2>/dev/null || true
timeout 40 systemctl start postgresql.service; echo pg-start-rc=\$?
sleep 1
systemctl is-active postgresql.service
echo == pg log ==
journalctl -u postgresql -n 30 --no-pager 2>/dev/null | tail -30
echo == pg query ==
su -s /bin/sh postgres -c \"psql -tAc \\\"select version();\\\"\" 2>&1 | head -3
echo == failed ==
systemctl --failed --no-pager
"' 2>&1 | grep -a -v "Permanently added"