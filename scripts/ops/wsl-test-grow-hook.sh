#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.103
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"
# extract hook from the new initramfs on the PC side (WSL did it), upload it
$SSH "$H" 'cat > /tmp/50-loop-root.sh' < /mnt/f/project/pmos-munch/work/grow-hook.sh 2>/dev/null || true
# fallback: use the copy inside the built initramfs path if present
ls -la /mnt/f/project/pmos-munch/work/grow-hook.sh 2>/dev/null || true
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh /tmp/50-loop-root.sh' 2>&1 | grep -a -v "Permanently added" || true
echo "=== loop status ==="
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "losetup -a; echo ---; cat /run/www/loop-root.log"' 2>&1 | grep -a -v "Permanently added"
