#!/bin/bash
# Offline end-to-end verification of the initramfs debug hooks under qemu-user.
# Run as root (sudo -n bash this_script).
set -uo pipefail
W=/mnt/f/project/pmos-munch/work/fatbuild
T=$W/qtest
PASS=0; FAIL=0
ok()   { echo "PASS: $*"; PASS=$((PASS+1)); }
bad()  { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

echo "########## setup chroot root ##########"
rm -rf "$T"; mkdir -p "$T"
cd "$T"
gzip -dc "$W/initramfs-fat.gz" | cpio -idm --quiet

echo "########## binfmt registration ##########"
if [ ! -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
	mkdir -p /proc/sys/fs/binfmt_misc
	mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc 2>/dev/null
	if [ -e /proc/sys/fs/binfmt_misc/register ]; then
		printf ':qemu-aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-aarch64-static:F' > /proc/sys/fs/binfmt_misc/register 2>/dev/null
	fi
fi
if [ -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then ok "binfmt qemu-aarch64 registered"; else bad "binfmt unavailable (chroot tests need it)"; fi

echo "########## bind mounts for chroot ##########"
mkdir -p "$T"/{proc,sys,dev,run}
mountpoint -q "$T/proc" || mount --bind /proc "$T/proc"
mountpoint -q "$T/sys"  || mount --bind /sys  "$T/sys"
mountpoint -q "$T/dev"  || mount --bind /dev  "$T/dev"
mountpoint -q "$T/run"  || mount -t tmpfs tmpfs "$T/run"
ok "bind mounts ready"

echo "########## chroot basic ##########"
if chroot "$T" /bin/sh -c 'echo CHROOT_OK'; then ok "chroot arm64 shell runs"; else bad "chroot shell"; fi

echo "########## static checks ##########"
grep -q "munch-early" "$T/init" && ok "/init early debug block present" || bad "/init block missing"
grep -q "munch: skipping dynamic partitions" "$T/init_2nd.sh" && ok "init_2nd super-partition skip patched" || bad "init_2nd patch missing"
for h in hooks/40-httpdebug.sh hooks/50-loop-root.sh hooks/60-diag.sh hooks-cleanup/90-reached.sh; do
	[ -f "$T/$h" ] && ok "hook $h exists" || bad "hook $h missing"
done

echo "########## hook 40: httpd test (port 80) ##########"
rm -rf "$T/run/www"
chroot "$T" /bin/sh /hooks/40-httpdebug.sh
sleep 1
CODE=$(curl -s -m 3 -o /dev/null -w "%{http_code}" "http://127.0.0.1/cgi-bin/run" 2>/dev/null)
if [ "$CODE" = "200" ]; then ok "httpd serving on :80 (200)"; else bad "httpd not serving (code=$CODE)"; fi
curl -s -m 3 -X POST --data 'echo HELLO_FROM_INITRAMFS; uname -m; id' "http://127.0.0.1/cgi-bin/put" >/dev/null 2>&1
OUT=$(curl -s -m 5 "http://127.0.0.1/cgi-bin/run" 2>/dev/null)
echo "CGI run output: $OUT"
echo "$OUT" | grep -q HELLO_FROM_INITRAMFS && ok "CGI exec works" || bad "CGI exec broken"

echo "########## hook 40: tcpsvd shell test (port 4444) ##########"
OUT2=$(timeout 5 bash -c 'exec 3<>/dev/tcp/127.0.0.1/4444; printf "echo TCP_SHELL_OK; exit\n" >&3; cat <&3' 2>/dev/null)
echo "TCP output: $OUT2"
echo "$OUT2" | grep -q TCP_SHELL_OK && ok "tcpsvd shell works on :4444" || bad "tcpsvd shell broken"

echo "########## hook 50: fake userdata loop test ##########"
DISK=$T/fakedisk.img
rm -f "$DISK" $T/part.vfat $T/rootfs.img
truncate -s 64M "$DISK"
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart userdata fat32 1MiB 63MiB
truncate -s 62M "$T/part.vfat"
mkfs.vfat -F 32 -n PMOSBOOT "$T/part.vfat" >/dev/null
truncate -s 8M "$T/rootfs.img"
mkfs.ext4 -q -F -L pmOS_root "$T/rootfs.img"
MTOOLS_SKIP_CHECK=1 mcopy -i "$T/part.vfat" "$T/rootfs.img" ::/rootfs.img
dd if="$T/part.vfat" of="$DISK" bs=1M seek=1 conv=notrunc status=none
LOOPD=$(losetup -f --show -P "$DISK")
sleep 1
echo "loop dev: $LOOPD"
blkid | grep -i userdata || echo "(no PARTLABEL seen yet)"
PART=$(ls ${LOOPD}p1 2>/dev/null || ls ${LOOPD}* 2>/dev/null | grep -v "^${LOOPD}$" | head -1)
echo "partition: $PART"
if [ -e "$PART" ]; then ok "fake userdata partition device exists"; else bad "no partition node"; fi
blkid --match-token PARTLABEL=userdata -o device
rm -f "$T/run/www/loop-root.log"
chroot "$T" /bin/sh /hooks/50-loop-root.sh
echo "--- loop-root.log ---"
cat "$T/run/www/loop-root.log" 2>/dev/null
grep -q "ext4 test mount OK" "$T/run/www/loop-root.log" 2>/dev/null && ok "hook50: vfat mount + losetup + ext4 mount OK" || bad "hook50 failed one of its steps"
losetup -D 2>/dev/null
echo "########## hook 60: diag ##########"
chroot "$T" /bin/sh /hooks/60-diag.sh
[ -s "$T/run/www/diag.txt" ] && ok "diag.txt generated ($(head -1 "$T/run/www/diag.txt"))" || bad "diag.txt missing"
head -12 "$T/run/www/diag.txt" 2>/dev/null

echo "########## cleanup ##########"
# kill httpd/tcpsvd started in chroot
pkill -f "qemu-aarch64-static.*httpd" 2>/dev/null
pkill -f "qemu-aarch64-static.*tcpsvd" 2>/dev/null
umount "$T/run" 2>/dev/null
umount "$T/dev" 2>/dev/null
umount "$T/sys" 2>/dev/null
umount "$T/proc" 2>/dev/null
losetup -D 2>/dev/null
echo
echo "########## RESULT: PASS=$PASS FAIL=$FAIL ##########"
