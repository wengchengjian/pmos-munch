#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@172.16.42.1
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"
$SSH "$H" 'cat > /tmp/wifi-reprovision.sh' < /mnt/f/project/pmos-munch/cmds/wifi-reprovision.sh || exit 1
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh /tmp/wifi-reprovision.sh' 2>&1 | grep -v "Permanently added" | tail -30
