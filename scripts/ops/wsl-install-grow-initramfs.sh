#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.103
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 -o ServerAliveInterval=15"
NEW=/mnt/f/project/pmos-munch/work/initramfs-grow.gz
echo "== e2fsck (read-only) =="
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" e2fsck -fn /dev/loop1' 2>&1 | grep -a -v "Permanently added" | tail -12
echo "== detach test loop =="
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" losetup -d /dev/loop1; losetup -a' 2>&1 | grep -a -v "Permanently added"
echo "== upload new initramfs =="
$SSH "$H" 'cat > /tmp/initramfs-new.gz' < "$NEW" || exit 1
L=$(sha256sum "$NEW" | awk '{print $1}')
R=$($SSH "$H" 'sha256sum /tmp/initramfs-new.gz' 2>/dev/null | awk '{print $1}')
echo "local=$L"; echo "remote=$R"
[ "$L" = "$R" ] || { echo "SHA MISMATCH"; exit 1; }
echo "== install (backup old) =="
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
cp -n /boot/boot/initramfs.gz /boot/boot/initramfs-old-rootfsimg.gz
cp /tmp/initramfs-new.gz /boot/boot/initramfs.gz
sync
sha256sum /boot/boot/initramfs.gz /boot/boot/initramfs-old-rootfsimg.gz
ls -la /boot/boot/
df -h /boot | tail -1
"' 2>&1 | grep -a -v "Permanently added"