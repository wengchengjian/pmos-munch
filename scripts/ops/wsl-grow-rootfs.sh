#!/bin/sh
# 在 userdata 的 1.5GiB FAT 之后创建大 ext4，并把当前 rootfs 复制过去。
# 不修改 FAT，不修改分区表；失败时旧 rootfs.img 仍可用于回退。
set -u
LOG=/root/grow.log
exec >>"$LOG" 2>&1
echo "=== grow-rootfs start $(date) ==="

P=/dev/sda34
OFF=1610612736   # 1536 MiB, after the FAT32 boot filesystem
LOOP=$(losetup -f)
[ -n "$LOOP" ] || { echo "FAIL: no free loop"; exit 1; }
echo "loop=$LOOP offset=$OFF"

losetup -o "$OFF" "$LOOP" "$P" || { echo "FAIL: losetup"; exit 1; }
echo "loop size: $(($(cat /sys/class/block/$(basename "$LOOP")/size) / 2048)) MiB"

echo "=== mkfs.ext4 ==="
mkfs.ext4 -F -m 0 -L pmOS_root \
  -U 687be8df-d76e-40ac-b251-8a4032ad04f3 \
  -E lazy_itable_init=1,lazy_journal_init=1 \
  "$LOOP" || { echo "FAIL: mkfs"; exit 1; }
echo "=== mkfs done ==="
blkid "$LOOP"

mkdir -p /mnt/newroot
mount "$LOOP" /mnt/newroot || { echo "FAIL: mount"; exit 1; }
echo "=== mounted ==="
df -h /mnt/newroot | tail -1

echo "=== rsync ==="
rsync -aHAX --numeric-ids --one-file-system \
  --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/run --exclude=/tmp \
  --exclude=/boot --exclude=/mnt --exclude=/media --exclude=/lost+found \
  --exclude=/var/cache/apk \
  / /mnt/newroot/
RC=$?
echo "=== rsync rc=$RC ==="
[ "$RC" -eq 0 ] || [ "$RC" -eq 24 ] || { echo "FAIL: rsync rc=$RC"; exit 1; }

mkdir -p /mnt/newroot/proc /mnt/newroot/sys /mnt/newroot/dev /mnt/newroot/run \
         /mnt/newroot/tmp /mnt/newroot/boot /mnt/newroot/mnt /mnt/newroot/media

echo "=== verify ==="
OK=1
test -x /mnt/newroot/usr/bin/tmux && echo "OK tmux" || { echo "MISS tmux"; OK=0; }
test -x /mnt/newroot/usr/local/bin/gpio_hold && echo "OK gpio_hold" || { echo "MISS gpio_hold"; OK=0; }
test -f /mnt/newroot/etc/systemd/system/panel-blank.service && echo "OK panel-blank" || { echo "MISS panel-blank"; OK=0; }
test -d "/mnt/newroot/usr/lib/modules/$(uname -r)" && echo "OK modules" || { echo "MISS modules"; OK=0; }
test -f /mnt/newroot/etc/wpa_supplicant/wpa_supplicant-wlan0.conf && echo "OK wifi-conf" || echo "warn: wifi-conf missing"
test -f /mnt/newroot/etc/ssh/ssh_host_ed25519_key && echo "OK ssh-hostkey" || echo "warn: ssh hostkey missing"
echo "bin -> $(readlink /mnt/newroot/bin)"
diff /etc/fstab /mnt/newroot/etc/fstab && echo "OK fstab" || { echo "DIFF fstab"; OK=0; }
du -sh /mnt/newroot
df -h /mnt/newroot | tail -1

if [ "$OK" -eq 1 ]; then
  sync
  umount /mnt/newroot
  losetup -d "$LOOP"
  echo "=== GROW_OK $(date) ==="
  echo ok > /root/grow-ok
  exit 0
else
  echo "=== GROW_FAILED (left mounted for inspection) $(date) ==="
  exit 1
fi
