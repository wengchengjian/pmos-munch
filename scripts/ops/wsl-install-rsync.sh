#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.103
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o ServerAliveInterval=15"
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
df -h / | tail -1
apk add rsync 2>&1 | tail -15
echo === verify ===
command -v rsync && rsync --version | head -1
df -h / | tail -1
"' 2>&1 | grep -a -v "Permanently added"