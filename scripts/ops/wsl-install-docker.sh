#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.100
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o ServerAliveInterval=15"
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
apk add docker docker-cli kmod iptables 2>&1 | tail -30
echo == binaries ==
for t in docker dockerd containerd runc iptables modprobe; do printf \"%-12s \" \$t; command -v \$t || echo MISSING; done
echo == shipped units ==
ls /usr/lib/systemd/system/ 2>/dev/null | grep -E \"docker|containerd|redis|postgres\" || true
echo == init scripts ==
ls /etc/init.d/ 2>/dev/null | grep -E \"docker|containerd|redis|postgres\" || true
echo == docker version ==
docker --version 2>/dev/null
dockerd --version 2>/dev/null
echo == space ==
df -h / | tail -1
"' 2>&1 | grep -a -v "Permanently added"