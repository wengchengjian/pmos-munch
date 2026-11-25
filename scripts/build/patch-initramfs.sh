#!/bin/bash
# Runs as root in WSL: extract initramfs, add debug/loop hooks, repack gzip.
# Round 4: verified offline with qemu-user (busybox-extras has httpd/tcpsvd).
set -euo pipefail
W=/mnt/f/project/pmos-munch/work/fatbuild
cd "$W"
rm -rf ird
mkdir -p ird
cd ird
gzip -dc ../initramfs.gz | cpio -idm --quiet

# ---- override deviceinfo (USB identity + skip super dynamic partitions) ----
DEV="$PWD/usr/share/deviceinfo/deviceinfo"
if [ -e "$DEV" ]; then
	cat >> "$DEV" <<'DEOF'

# munch FAT32-UEFI build overrides
deviceinfo_usb_idVendor="0x1d6b"
deviceinfo_usb_idProduct="0x0104"
deviceinfo_usb_serialnumber="pmos-munch"
deviceinfo_usb_network_function="ncm.usb0"
deviceinfo_super_partitions=""
DEOF
	grep -n "deviceinfo_usb\|super_partitions" "$DEV" | tail -6 || true
fi

# ---- patch /init: start HTTP debug shell as early as stage 1 ----
python3 - <<'PYEOF'
block = r'''
# --- munch early debug: HTTP shell (stage 1, before any disk access) ---
mkdir -p /run/www/cgi-bin
printf '%s\n' '#!/bin/sh' 'cat > /run/cmds' 'printf "Content-Type: text/plain\r\n\r\n"' 'echo OK' > /run/www/cgi-bin/put
printf '%s\n' '#!/bin/sh' 'printf "Content-Type: text/plain\r\n\r\n"' 'exec /bin/sh /run/cmds 2>&1' > /run/www/cgi-bin/run
chmod 755 /run/www/cgi-bin/put /run/www/cgi-bin/run
echo "munch-early: cgi ready" > /dev/kmsg 2>/dev/null
/bin/busybox-extras httpd -p 80 -h /run/www 2>/dev/null
echo "munch-early: httpd rc=$?" > /dev/kmsg 2>/dev/null
/bin/busybox-extras tcpsvd 0.0.0.0 4444 /bin/sh >/dev/null 2>&1 &
# --- end munch early debug ---
'''
p = 'init'
s = open(p).read()
if 'munch-early' not in s:
    assert '\nsetup_log\n' in s, 'setup_log anchor missing'
    s = s.replace('\nsetup_log\n', '\nsetup_log\n' + block, 1)
    open(p, 'w').write(s)
    print("init patched")
else:
    print("init already patched")
PYEOF
grep -n "munch early debug" init | head -2

# ---- /init_2nd.sh: drop super-partition dm mapping (not needed; avoids hangs) ----
python3 - <<'PYEOF'
p = 'init_2nd.sh'
s = open(p).read()
old = 'setup_dynamic_partitions "${deviceinfo_super_partitions:=}"'
new = 'echo "munch: skipping dynamic partitions"'
if old in s:
    open(p, 'w').write(s.replace(old, new, 1))
    print("init_2nd patched")
else:
    print("init_2nd: anchor not found (ok?)")
PYEOF
grep -n "dynamic partitions" init_2nd.sh | head -3

# ---- hook 40: ensure httpd + tcpsvd shell up in stage 2 as well ----
mkdir -p hooks
cat > hooks/40-httpdebug.sh <<'H1'
#!/bin/sh
mkdir -p /run/www/cgi-bin
printf '%s\n' '#!/bin/sh' 'cat > /run/cmds' 'printf "Content-Type: text/plain\r\n\r\n"' 'echo OK' > /run/www/cgi-bin/put
printf '%s\n' '#!/bin/sh' 'printf "Content-Type: text/plain\r\n\r\n"' 'exec /bin/sh /run/cmds 2>&1' > /run/www/cgi-bin/run
chmod 755 /run/www/cgi-bin/put /run/www/cgi-bin/run
if ! grep -q ":0050 " /proc/net/tcp 2>/dev/null; then
	/bin/busybox-extras httpd -p 80 -h /run/www 2>/dev/null
	echo "httpdebug: httpd rc=$?" > /dev/kmsg 2>/dev/null
fi
if ! grep -q ":115C " /proc/net/tcp 2>/dev/null; then
	/bin/busybox-extras tcpsvd 0.0.0.0 4444 /bin/sh >/dev/null 2>&1 &
fi
echo "httpdebug: done" > /dev/kmsg 2>/dev/null
H1
chmod 755 hooks/40-httpdebug.sh

# ---- hook 50: attach rootfs.img as a loop device (with logging) ----
cat > hooks/50-loop-root.sh <<'H2'
#!/bin/sh
LOG=/run/www/loop-root.log
mkdir -p /run/www
: > "$LOG"
say() { echo "$*" >> "$LOG"; echo "loop-root: $*" > /dev/kmsg 2>/dev/null; }
say "start"
P=""
i=0
while [ "$i" -lt 120 ]; do
	P=$(blkid --match-token PARTLABEL=userdata -o device 2>/dev/null | head -n 1)
	[ -n "$P" ] && break
	D=""
	for u in /sys/class/block/*/uevent; do
		if grep -q '^PARTNAME=userdata$' "$u" 2>/dev/null; then
			D=$(basename "$(dirname "$u")")
			break
		fi
	done
	if [ -n "$D" ]; then
		P="/dev/$D"
		break
	fi
	sleep 0.5
	i=$((i+1))
done
say "partition=$P"
[ -n "$P" ] || exit 1
mkdir -p /run/rootimg-fat
if ! mount -t vfat -o rw "$P" /run/rootimg-fat; then
	say "vfat mount FAILED"
	exit 1
fi
say "vfat mounted"
[ -f /run/rootimg-fat/rootfs.img ] || { say "rootfs.img missing"; exit 1; }
LOOP=$(losetup -f 2>/dev/null)
[ -n "$LOOP" ] || LOOP=/dev/loop0
say "loop=$LOOP"
if ! losetup "$LOOP" /run/rootimg-fat/rootfs.img; then
	say "losetup FAILED"
	exit 1
fi
say "losetup ok"
say "blkid loop: $(blkid "$LOOP" 2>&1)"
mkdir -p /mnt2
if mount -t ext4 -o ro "$LOOP" /mnt2; then
	say "ext4 test mount OK: $(ls /mnt2 2>/dev/null | head -5 | tr '\n' ' ')"
	umount /mnt2
else
	say "ext4 test mount FAILED"
fi
H2
chmod 755 hooks/50-loop-root.sh

# ---- hook 60: full diagnostics dump (served over http + FAT copy) ----
cat > hooks/60-diag.sh <<'H3'
#!/bin/sh
OUT=/run/www/diag.txt
{
	echo "== cmdline =="; cat /proc/cmdline
	echo "== uname =="; uname -a
	echo "== block devices =="; ls -l /dev/sd* /dev/loop* 2>&1 | head -40
	echo "== blkid =="; blkid 2>&1
	echo "== losetup -a =="; losetup -a 2>&1
	echo "== mounts =="; mount 2>&1
	echo "== loop-root.log =="; cat /run/www/loop-root.log 2>&1
	echo "== dmesg tail =="; dmesg | tail -400
} > "$OUT" 2>&1
cp "$OUT" /run/rootimg-fat/diag.txt 2>/dev/null
echo "diag: written" > /dev/kmsg 2>/dev/null
H3
chmod 755 hooks/60-diag.sh

# ---- marker if we reach the pre-switch_root point ----
mkdir -p hooks-cleanup
cat > hooks-cleanup/90-reached.sh <<'H4'
#!/bin/sh
echo "reached /hooks-cleanup at $(date)" > /run/www/state-last.txt
echo "reached pre-switch_root" > /dev/kmsg 2>/dev/null
H4
chmod 755 hooks-cleanup/90-reached.sh

find . -print0 | cpio --null -o -H newc --quiet | gzip -9 > ../initramfs-fat.gz
echo "repacked initramfs: $(stat -c %s ../initramfs-fat.gz) bytes"
