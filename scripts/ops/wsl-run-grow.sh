#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.103
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o ServerAliveInterval=15"
$SSH "$H" 'cat > /tmp/grow-rootfs.sh' < /mnt/f/project/pmos-munch/work/grow-rootfs.sh || exit 1
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh /tmp/grow-rootfs.sh' 2>&1 | grep -a -v "Permanently added"
echo "=== grow.log ==="
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" cat /root/grow.log' 2>&1 | grep -a -v "Permanently added" | tail -40
