#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.100
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o ServerAliveInterval=15"
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
echo == compose plugin ==
apk add docker-cli-compose 2>&1 | tail -5
docker compose version 2>&1 | head -1
echo == docker pull hello-world ==
timeout 120 docker run --rm hello-world 2>&1 | tail -15
RC=\$?
echo hello-world-rc=\$RC
if [ \$RC -ne 0 ]; then
  echo == local busybox image test ==
  rm -rf /tmp/docker-test && mkdir -p /tmp/docker-test/bin /tmp/docker-test/lib
  cp /bin/busybox /tmp/docker-test/bin/
  ln -sf busybox /tmp/docker-test/bin/sh
  cp -L /lib/ld-musl-aarch64.so.1 /tmp/docker-test/lib/ 2>/dev/null || true
  cp -L /lib/libc.musl-aarch64.so.1 /tmp/docker-test/lib/ 2>/dev/null || true
  tar -C /tmp/docker-test -cf /tmp/docker-test.tar .
  docker import /tmp/docker-test.tar busybox-local:test 2>&1 | tail -2
  timeout 60 docker run --rm busybox-local:test /bin/sh -c \"echo DOCKER_OK; uname -m\" 2>&1 | tail -5
  echo local-rc=\$?
fi
echo == docker ps ==
docker ps -a 2>&1 | head -5
echo == images ==
docker images 2>&1 | head -5
"' 2>&1 | grep -a -v "Permanently added"
echo "== npm/pip mirrors =="
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
npm config set registry https://registry.npmmirror.com --location=global 2>&1 | tail -2
su -s /bin/sh user -c \"npm config set registry https://registry.npmmirror.com\" 2>&1 | tail -2
printf \"[global]\nindex-url = https://mirrors.aliyun.com/pypi/simple/\ntrusted-host = mirrors.aliyun.com\n\" > /etc/pip.conf
cat /etc/pip.conf
su -s /bin/sh user -c \"npm config get registry\"
pip3 config get global.index-url 2>&1
npm config get registry 2>&1
"' 2>&1 | grep -a -v "Permanently added"