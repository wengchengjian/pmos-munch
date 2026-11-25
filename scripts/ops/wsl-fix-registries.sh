#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.100
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o ServerAliveInterval=15"
$SSH "$H" 'cat > /tmp/docker-daemon.json' < /mnt/f/project/pmos-munch/units/docker-daemon.json || exit 1
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
echo == docker daemon config ==
install -m 644 /tmp/docker-daemon.json /etc/docker/daemon.json
systemctl daemon-reload
systemctl restart docker.service
sleep 3
systemctl is-active docker.service
docker info 2>/dev/null | grep -A3 -E \"Registry Mirrors|DNS Servers\" | head -10
echo == apk repo cleanup ==
grep -v \"mirrors.aliyun.com/postmarketOS/main\" /etc/apk/repositories > /tmp/repos
cat /tmp/repos > /etc/apk/repositories
apk update 2>&1 | tail -8
apk add docker-cli-compose 2>&1 | tail -6
docker compose version 2>&1 | head -1
echo == docker pull test ==
timeout 180 docker run --rm hello-world 2>&1 | tail -12
echo docker-run-rc=\$?
echo == images ==
docker images 2>&1 | head -5
"' 2>&1 | grep -a -v "Permanently added"