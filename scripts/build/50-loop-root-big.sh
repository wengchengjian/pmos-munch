#!/bin/sh
# munch: attach the big ext4 living at offset 1536MiB inside /dev/sda34
# (userdata). Fall back to the old rootfs.img on the FAT if anything fails.
LOG=/run/www/loop-root.log
mkdir -p /run/www
: > "$LOG"
say() { echo "$*" >> "$LOG"; echo "loop-root: $*" > /dev/kmsg 2>/dev/null; }
say "start (big-root mode)"

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

BIG_UUID=687be8df-d76e-40ac-b251-8a4032ad04f3
OFF=1610612736   # 1536 MiB: right after the FAT32 boot filesystem
LOOP=$(losetup -f 2>/dev/null)
[ -n "$LOOP" ] || LOOP=/dev/loop0
if losetup -o "$OFF" "$LOOP" "$P" 2>/dev/null; then
	UUID=$(blkid -s UUID -o value "$LOOP" 2>/dev/null | head -n 1)
	say "offset loop $LOOP uuid=$UUID"
	mkdir -p /mnt2
	if [ "$UUID" = "$BIG_UUID" ] && mount -t ext4 -o ro "$LOOP" /mnt2 2>/dev/null; then
		say "big rootfs OK: $(ls /mnt2 2>/dev/null | head -5 | tr '\n' ' ')"
		umount /mnt2
		exit 0
	fi
	say "big rootfs unusable; falling back"
	losetup -d "$LOOP" 2>/dev/null
else
	say "offset losetup FAILED; falling back"
fi

# ---- fallback: old rootfs.img on the FAT ----
mkdir -p /run/rootimg-fat
if ! mount -t vfat -o rw "$P" /run/rootimg-fat; then
	say "vfat mount FAILED"
	exit 1
fi
say "vfat mounted (fallback)"
[ -f /run/rootimg-fat/rootfs.img ] || { say "rootfs.img missing"; exit 1; }
LOOP=$(losetup -f 2>/dev/null)
[ -n "$LOOP" ] || LOOP=/dev/loop0
if ! losetup "$LOOP" /run/rootimg-fat/rootfs.img; then
	say "fallback losetup FAILED"
	exit 1
fi
say "fallback rootfs.img attached on $LOOP"
mkdir -p /mnt2
if mount -t ext4 -o ro "$LOOP" /mnt2 2>/dev/null; then
	say "fallback test mount OK"
	umount /mnt2
else
	say "fallback test mount FAILED"
fi
