#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.100
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
echo == resolv.conf ==
ls -l /etc/resolv.conf
cat /etc/resolv.conf
echo == resolved ==
systemctl is-active systemd-resolved 2>/dev/null; systemctl is-enabled systemd-resolved 2>/dev/null
echo == apk repos ==
cat /etc/apk/repositories
echo == dns lookups ==
for h in mirrors.aliyun.com registry.npmmirror.com docker.m.daocloud.io docker.1ms.run registry-1.docker.io; do printf \"%-28s \" \$h; getent hosts \$h | head -1 || echo FAIL; done
echo == curl ==
for u in https://mirrors.aliyun.com/alpine/edge/main/APKINDEX.tar.gz https://registry.npmmirror.com/ https://docker.m.daocloud.io/v2/ https://docker.1ms.run/v2/; do printf \"%s -> \" \$u; curl -sI -m 8 -o /dev/null -w \"%{http_code}\n\" \$u || echo FAIL; done
echo == npm configs ==
npm config get registry 2>&1
npm config get globalconfig 2>&1
ls -la /home/user/.npmrc /usr/etc/npmrc /etc/npmrc 2>/dev/null
cat /home/user/.npmrc 2>/dev/null
echo == pip config ==
pip3 config debug 2>&1 | head -20
"' 2>&1 | grep -a -v "Permanently added"