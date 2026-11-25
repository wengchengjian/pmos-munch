#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.100
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o ServerAliveInterval=15"
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
echo == install nodejs/npm/redis/postgresql17 ==
apk add nodejs npm redis postgresql17 2>&1 | tail -50
echo == versions ==
node -v 2>/dev/null; npm -v 2>/dev/null
redis-server --version 2>/dev/null
postgres --version 2>/dev/null
echo == users/dirs ==
id redis 2>/dev/null
id postgres 2>/dev/null
ls -ld /var/lib/redis /var/lib/postgresql 2>/dev/null
echo == configs ==
ls -la /etc/redis.conf 2>/dev/null
ls -la /usr/bin/initdb /usr/bin/postgres 2>/dev/null
echo == space ==
df -h / | tail -1
"' 2>&1 | grep -a -v "Permanently added"