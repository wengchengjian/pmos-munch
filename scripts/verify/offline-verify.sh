#!/bin/bash
# Offline verification (SAFE: proot + qemu-user, no binfmt changes).
# Run as root: sudo -n bash this_script
set -uo pipefail
W=/mnt/f/project/pmos-munch/work/fatbuild
T=$W/qtest2
QEMU=/usr/bin/qemu-aarch64-static
PASS=0; FAIL=0
ok()  { echo "PASS: $*"; PASS=$((PASS+1)); }
bad() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

echo "########## extract fresh initramfs ##########"
rm -rf "$T"; mkdir -p "$T"
cd "$T"
gzip -dc "$W/initramfs-fat.gz" | cpio -idm --quiet
ok "extracted"

echo "########## static checks ##########"
grep -q "munch-early" init && ok "/init early block" || bad "/init early block"
grep -q "munch: skipping dynamic partitions" init_2nd.sh && ok "init_2nd skip dm" || bad "init_2nd skip dm"
grep -q "busybox-extras httpd" init && ok "/init uses busybox-extras httpd" || bad "/init httpd binary"
grep -q "busybox-extras tcpsvd" init && ok "/init tcpsvd shell" || bad "tcpsvd missing"
grep -q "deviceinfo_super_partitions=\"\"" usr/share/deviceinfo/device-xiaomi-munch && ok "deviceinfo super disabled" || bad "deviceinfo super"
grep -q "0x1d6b" usr/share/deviceinfo/device-xiaomi-munch && ok "deviceinfo USB 1d6b:0104" || bad "deviceinfo usb"

echo "########## hook 40 exact run via proot (daemonizing; hard timeout) ##########"
mkdir -p "$T/runhost"
PROOT_CMD="proot -q $QEMU -r $T -b /proc -b /sys -b /dev -b $T/runhost:/run -w /"
timeout 20 $PROOT_CMD /bin/sh /hooks/40-httpdebug.sh >/dev/null 2>&1 || true
sleep 1
echo "-- loop-root style check: /run content --"
ls -la "$T/runhost/www/cgi-bin" 2>/dev/null | head -5
if [ -x "$T/runhost/www/cgi-bin/run" ]; then ok "hook40 wrote cgi scripts"; else bad "cgi scripts missing"; fi
# try to curl the daemon (may have died with proot; that's ok, tested below foreground)
CODE=$(curl -s -m 2 -o /dev/null -w "%{http_code}" "http://127.0.0.1/" 2>/dev/null)
echo "daemon http code: ${CODE:-none}"

echo "########## httpd foreground + CGI test (port 8080) ##########"
timeout 40 $PROOT_CMD /bin/busybox-extras httpd -f -p 8080 -h /run/www >/dev/null 2>&1 &
HPID=$!
sleep 1
CODE=$(curl -s -m 3 -o /dev/null -w "%{http_code}" "http://127.0.0.1:8080/cgi-bin/run" 2>/dev/null)
[ "$CODE" = "200" ] && ok "httpd :8080 serving (200)" || bad "httpd :8080 (code=$CODE)"
curl -s -m 3 -X POST --data 'echo HELLO_CGI; uname -m' "http://127.0.0.1:8080/cgi-bin/put" >/dev/null 2>&1
OUT=$(curl -s -m 5 "http://127.0.0.1:8080/cgi-bin/run" 2>/dev/null)
echo "CGI output: $OUT"
echo "$OUT" | grep -q HELLO_CGI && ok "CGI exec via proot" || bad "CGI exec via proot"
kill $HPID 2>/dev/null; wait $HPID 2>/dev/null

echo "########## tcpsvd shell test (port 4444) ##########"
timeout 30 $PROOT_CMD /bin/busybox-extras tcpsvd 0.0.0.0 4444 /bin/sh >/dev/null 2>&1 &
TPID=$!
sleep 1
OUT2=$(timeout 5 bash -c 'exec 3<>/dev/tcp/127.0.0.1/4444; printf "echo TCP_SHELL_OK; exit\n" >&3; cat <&3' 2>/dev/null)
echo "TCP output: $OUT2"
echo "$OUT2" | grep -q TCP_SHELL_OK && ok "tcpsvd shell :4444" || bad "tcpsvd shell"
kill $TPID 2>/dev/null; wait $TPID 2>/dev/null

echo "########## hook 50 logic with REAL initramfs binaries (fake disk) ##########"
DISK=$T/fakedisk.img
truncate -s 64M "$DISK"
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart userdata fat32 1MiB 63MiB
truncate -s 62M "$T/part.vfat"
mkfs.vfat -F 32 -n PMOSBOOT "$T/part.vfat" >/dev/null
truncate -s 8M "$T/rootfs.img"
mkfs.ext4 -q -F -L pmOS_root "$T/rootfs.img"
MTOOLS_SKIP_CHECK=1 mcopy -i "$T/part.vfat" "$T/rootfs.img" ::/rootfs.img
dd if="$T/part.vfat" of="$DISK" bs=1M seek=1 conv=notrunc status=none
DISKLOOP=$(losetup -f --show -P "$DISK")
sleep 1
PART="${DISKLOOP}p1"
echo "disk loop: $DISKLOOP part: $PART"
[ -b "$PART" ] && ok "fake userdata partition exists" || bad "partition missing"

# a) PARTLABEL detection with initramfs blkid
DET=$($QEMU -L "$T" "$T/usr/bin/blkid" --match-token PARTLABEL=userdata -o device 2>/dev/null | head -1)
echo "blkid detected: $DET"
[ "$DET" = "$PART" ] && ok "initramfs blkid PARTLABEL=userdata -> $PART" || bad "blkid PARTLABEL detection ($DET)"

# b) vfat mount with initramfs busybox
mkdir -p /mnt/fakefat
if $QEMU -L "$T" "$T/bin/busybox" mount -t vfat -o rw "$PART" /mnt/fakefat 2>/dev/null; then
	ok "initramfs busybox mount vfat"
	[ -f /mnt/fakefat/rootfs.img ] && ok "rootfs.img visible on vfat" || bad "rootfs.img missing"
else
	bad "busybox mount vfat"
fi

# c) losetup attach with initramfs losetup
FL=$($QEMU -L "$T" "$T/usr/bin/losetup" -f 2>/dev/null)
echo "free loop (initramfs losetup): $FL"
if $QEMU -L "$T" "$T/usr/bin/losetup" "$FL" /mnt/fakefat/rootfs.img 2>/dev/null; then
	ok "initramfs losetup attach rootfs.img -> $FL"
else
	bad "initramfs losetup attach"
fi

# d) UUID discoverable like pmOS find_partition does
U=$($QEMU -L "$T" "$T/usr/bin/blkid" -s UUID -o value "$FL" 2>/dev/null | head -1)
echo "ext4 UUID on $FL: $U"
[ -n "$U" ] && ok "ext4 UUID readable from loop device" || bad "ext4 UUID"

# e) ext4 mount test like hook
mkdir -p /mnt/fakeroot
if $QEMU -L "$T" "$T/bin/busybox" mount -t ext4 -o ro "$FL" /mnt/fakeroot 2>/dev/null; then
	ok "ext4 mount of rootfs.img loop OK"
	$QEMU -L "$T" "$T/bin/busybox" umount /mnt/fakeroot
else
	bad "ext4 mount"
fi
$QEMU -L "$T" "$T/bin/busybox" umount /mnt/fakefat 2>/dev/null
losetup -d "$DISKLOOP" 2>/dev/null

echo "########## hook 60 diag via proot ##########"
timeout 20 $PROOT_CMD /bin/sh /hooks/60-diag.sh >/dev/null 2>&1 || true
[ -s "$T/runhost/www/diag.txt" ] && ok "diag.txt generated" || bad "diag.txt missing"
head -8 "$T/runhost/www/diag.txt" 2>/dev/null

echo "########## cleanup ##########"
kill $HPID $TPID 2>/dev/null || true
pkill -f "[h]ttpd -f -p 8080" 2>/dev/null || true
pkill -f "[t]cpsvd 0.0.0.0 4444" 2>/dev/null || true
pkill -f "[q]emu-aarch64-static" 2>/dev/null || true
pkill -f "httpd -f -p 8080" 2>/dev/null
pkill -f "tcpsvd 0.0.0.0 4444" 2>/dev/null
losetup -D 2>/dev/null
echo
echo "########## RESULT: PASS=$PASS FAIL=$FAIL ##########"
