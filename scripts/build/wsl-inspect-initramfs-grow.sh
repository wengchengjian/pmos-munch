#!/bin/bash
set -u
cd /mnt/f/project/pmos-munch/work/initramfs-grow || exit 1
rm -rf ./*
gzip -dc /mnt/f/project/pmos-munch/out/backup-20261125-133425/initramfs.gz | cpio -idm --quiet
echo "=== existing hook ==="
cat hooks/50-loop-root.sh
echo "=== losetup ==="
ls -la usr/bin/losetup usr/sbin/losetup bin/losetup 2>/dev/null
file usr/bin/losetup 2>/dev/null
echo "=== qemu ==="
Q=$(command -v qemu-aarch64-static || command -v qemu-aarch64 || true)
echo "qemu=$Q"
if [ -n "$Q" ]; then
  echo "--- losetup help ---"
  $Q -L . usr/bin/losetup --help 2>&1 | grep -E "offset|sizelimit" | head -4
  echo "--- blkid help ---"
  ls -la usr/sbin/blkid usr/bin/blkid 2>/dev/null
  $Q -L . usr/sbin/blkid --help 2>&1 | grep -E "\-\-size|\-o|\-s" | head -6
fi
echo "=== hooks list ==="
ls -la hooks
