#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.103
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6"
$SSH "$H" 'cat > /tmp/pinmac.sh' < /mnt/f/project/pmos-munch/cmds/pin-wifi-mac.sh
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh /tmp/pinmac.sh' 2>&1 | grep -v "Permanently added" | head -25
echo "=== reboot ==="
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" reboot' 2>/dev/null || true
echo "reboot sent"
