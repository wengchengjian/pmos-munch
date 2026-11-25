#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.100
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
echo == before ==
resolvectl status 2>&1 | head -30
echo == upstream file ==
cat /run/systemd/resolve/resolv.conf 2>/dev/null
echo == write resolved config ==
mkdir -p /etc/systemd/resolved.conf.d
cat > /etc/systemd/resolved.conf.d/10-dns.conf <<EOF
[Resolve]
DNS=192.168.0.1 223.5.5.5 8.8.8.8
FallbackDNS=1.1.1.1 9.9.9.9
Domains=~.
EOF
systemctl restart systemd-resolved
sleep 2
resolvectl flush-caches 2>/dev/null || true
echo == after ==
resolvectl status 2>&1 | head -25
echo == lookups ==
for h in registry.npmmirror.com docker.m.daocloud.io docker.1ms.run mirrors.aliyun.com registry-1.docker.io; do printf \"%-28s \" \$h; getent hosts \$h | head -1 || echo FAIL; done
echo == curl ==
for u in https://registry.npmmirror.com/ https://docker.1ms.run/v2/ https://docker.m.daocloud.io/v2/ https://mirrors.aliyun.com/alpine/edge/main/APKINDEX.tar.gz; do printf \"%s -> \" \$u; curl -s -m 10 -o /dev/null -w \"%{http_code}\n\" \$u || echo FAIL; done
"' 2>&1 | grep -a -v "Permanently added"