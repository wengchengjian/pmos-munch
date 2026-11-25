#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.100
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
echo == redis log ==
tail -30 /var/log/redis/redis.log 2>/dev/null || echo no-log
echo == config ==
grep -nE \"^(daemonize|supervised|pidfile|unixsocket|unixsocketperm|logfile|dir|bind|port|protected-mode|appendonly|save)\" /etc/redis.conf | head -40
echo == dirs ==
ls -ld /run/redis /var/log/redis /var/lib/redis 2>&1
echo == manual start ==
timeout 6 su -s /bin/sh redis -c \"/usr/sbin/redis-server /etc/redis.conf --daemonize no --logfile /dev/stdout\" 2>&1 | tail -25
echo == end ==
"' 2>&1 | grep -a -v "Permanently added"