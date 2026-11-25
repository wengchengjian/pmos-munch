#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.100
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o ServerAliveInterval=15"
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
apk add git make gcc musl-dev pkgconf python3 py3-pip vim nano htop strace lsof ncdu unzip zip tcpdump sqlite openssl bash-completion 2>&1 | tail -45
echo === verify ===
for t in git python3 pip3 gcc make vim nano htop strace lsof ncdu unzip zip tcpdump sqlite3 openssl; do printf \"%-10s \" \$t; command -v \$t || echo MISSING; done
echo === versions ===
git --version 2>/dev/null
python3 -V 2>/dev/null
gcc --version 2>/dev/null | head -1
make --version 2>/dev/null | head -1
vim --version 2>/dev/null | head -1
echo === space ===
df -h / | tail -1
echo === world ===
cat /etc/apk/world
"' 2>&1 | grep -a -v "Permanently added"