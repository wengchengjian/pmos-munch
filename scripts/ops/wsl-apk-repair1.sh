#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.103
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"
echo "== repo reachability =="
$SSH "$H" 'for u in https://mirrors.aliyun.com/postmarketOS/main https://mirrors.aliyun.com/alpine/edge/main https://mirror.nura.eco/postmarketos/extra-repos/systemd/main; do printf "%s -> " "$u"; wget -q -T 8 -O /tmp/idx.tgz "$u/APKINDEX.tar.gz" && stat -c %s /tmp/idx.tgz || echo FAIL; done' 2>&1 | grep -a -v "Permanently added"
echo "== configure mirrors + repair db =="
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
cp /etc/apk/repositories /etc/apk/repositories.bak
printf \"https://mirrors.aliyun.com/postmarketOS/main\nhttps://mirrors.aliyun.com/alpine/edge/main\nhttps://mirrors.aliyun.com/alpine/edge/community\nhttps://mirrors.aliyun.com/alpine/edge/testing\n\" > /etc/apk/repositories
cat /etc/apk/repositories
mv /lib/apk/db/installed /lib/apk/db/installed.corrupt
apk update 2>&1 | tail -8
ls -la /lib/apk/db/
"' 2>&1 | grep -a -v "Permanently added" | tail -25
