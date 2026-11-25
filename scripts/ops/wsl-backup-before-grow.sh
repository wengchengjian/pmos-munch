#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.103
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o ServerAliveInterval=15"
TS=$(date +%Y%m%d-%H%M%S)
B=/mnt/f/project/pmos-munch/out/backup-$TS
mkdir -p "$B"
echo "backup dir: $B"
echo "== saving boot files =="
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "cat /boot/initramfs.gz"' > "$B/initramfs.gz" 2>/dev/null
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "cat /boot/grub.cfg"' > "$B/grub.cfg" 2>/dev/null
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "tar -czf - /etc /root/.ssh /home/user/.ssh 2>/dev/null"' > "$B/etc-config.tar.gz" 2>/dev/null
ls -la "$B"
echo "== reading first 1536 MiB of /dev/sda34 =="
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" dd if=/dev/sda34 bs=1M count=1536 2>/tmp/dd.err' > "$B/sda34-first1536m.img" 2>/dev/null
echo "dd stderr:"; $SSH "$H" 'cat /tmp/dd.err' 2>/dev/null
ls -la "$B/sda34-first1536m.img"
sha256sum "$B/sda34-first1536m.img" "$B/initramfs.gz" "$B/etc-config.tar.gz" | tee "$B/SHA256SUMS"
echo "$B" > /tmp/last-backup-dir