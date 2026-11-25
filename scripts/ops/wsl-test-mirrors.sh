#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.100
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o ServerAliveInterval=15"
echo "== npm =="
$SSH "$H" 'su -s /bin/sh user -c "npm config get registry; npm view express version 2>&1 | tail -3"' 2>&1 | grep -a -v "Permanently added"
echo "== npm install test =="
$SSH "$H" 'rm -rf /tmp/npm-test && mkdir -p /tmp/npm-test && cd /tmp/npm-test && su -s /bin/sh user -c "cd /tmp/npm-test && npm init -y >/dev/null 2>&1 && npm install lodash --no-audit --no-fund 2>&1 | tail -5 && node -e \"console.log(require(\\\"lodash\\\").VERSION)\""' 2>&1 | grep -a -v "Permanently added"
echo "== pip =="
$SSH "$H" 'su -s /bin/sh user -c "pip3 config list 2>&1 | head -5; rm -rf /tmp/pip-test; pip3 download --no-deps -d /tmp/pip-test six 2>&1 | grep -E \"Looking in indexes|Saved|Successfully\" | head -5; ls -la /tmp/pip-test"' 2>&1 | grep -a -v "Permanently added"
echo "== container dns =="
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
timeout 120 docker run --rm alpine cat /etc/resolv.conf 2>&1 | head -6
timeout 120 docker run --rm alpine nslookup mirrors.aliyun.com 2>&1 | tail -6
"' 2>&1 | grep -a -v "Permanently added"
echo "== apk =="
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "apk update 2>&1 | tail -5; apk policy nodejs | head -4"' 2>&1 | grep -a -v "Permanently added"