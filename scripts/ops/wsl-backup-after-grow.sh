#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.100
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o ServerAliveInterval=15"
TS=$(date +%Y%m%d-%H%M%S)
OUT=/mnt/f/project/pmos-munch/out
echo "== backup new FAT (1.5GiB) =="
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" dd if=/dev/sda34 bs=1M count=1536 2>/tmp/dd2.err' > "$OUT/pmos-fat-userdata-grow.img" 2>/dev/null
$SSH "$H" 'cat /tmp/dd2.err' 2>/dev/null
ls -la "$OUT/pmos-fat-userdata-grow.img"
sha256sum "$OUT/pmos-fat-userdata-grow.img" | tee "$OUT/pmos-fat-userdata-grow.img.sha256"
echo "== backup current rootfs as tar.gz (live) =="
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "tar -C / --exclude=./proc --exclude=./sys --exclude=./dev --exclude=./run --exclude=./tmp --exclude=./boot --exclude=./mnt --exclude=./media --exclude=./lost+found --exclude=./var/cache/apk -czf - . 2>/tmp/tar.err"' > "$OUT/rootfs-grow-$TS.tar.gz" 2>/dev/null
$SSH "$H" 'cat /tmp/tar.err' 2>/dev/null | tail -5
ls -la "$OUT/rootfs-grow-$TS.tar.gz"
sha256sum "$OUT/rootfs-grow-$TS.tar.gz" | tee "$OUT/rootfs-grow-$TS.tar.gz.sha256"
echo "== verify tar list =="
tar -tzf "$OUT/rootfs-grow-$TS.tar.gz" 2>/dev/null | head -8
tar -tzf "$OUT/rootfs-grow-$TS.tar.gz" 2>/dev/null | wc -l