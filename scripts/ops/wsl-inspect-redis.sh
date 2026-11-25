#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.100
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
echo == cat unit ==
systemctl cat redis.service
echo == show ==
systemctl show redis.service -p Type -p ActiveState -p SubState -p ExecMainPID -p Result -p NRestarts
echo == status ==
systemctl status redis.service --no-pager -l 2>&1 | head -25
echo == log ==
journalctl -u redis -n 30 --no-pager 2>/dev/null | tail -30
echo == ping ==
redis-cli ping 2>&1
ps aux | grep -E \"[r]edis-server\" | head -3
"' 2>&1 | grep -a -v "Permanently added"