#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.100
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
echo == packages ==
for p in nodejs npm redis postgresql postgresql17 postgresql16 mariadb docker docker-cli containerd runc nginx caddy; do
  printf \"%-12s \" \$p
  apk search -x \$p 2>/dev/null | head -1 || true
done
echo == versions available ==
apk policy nodejs redis postgresql docker 2>/dev/null | head -40
echo == memory ==
grep -E \"MemTotal|MemAvailable\" /proc/meminfo
"' 2>&1 | grep -a -v "Permanently added"