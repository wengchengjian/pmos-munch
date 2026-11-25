#!/bin/bash
# Verify EDK2 (AAVMF) can read our 4096-byte-sector FAT32 and launch GRUB.
set -u
cd /mnt/f/project/pmos-munch
LOG=/mnt/f/project/pmos-munch/work/qemu-fat4096.log
timeout 100 qemu-system-aarch64 \
  -machine virt -cpu cortex-a72 -m 2048 -smp 2 \
  -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
  -drive file=out/pmos-fat-userdata.img,if=virtio,format=raw \
  -nographic -no-reboot \
  > "$LOG" 2>&1
echo "qemu exit=$? (124=timeout, expected if GRUB waits)"
echo "=== log size: $(stat -c %s "$LOG") bytes ==="
echo "=== markers ==="
grep -an "GRUB\|postmarketOS\|error:\|PMOSBOOT\|Boot Manager\|autoboot\|kernel" "$LOG" | head -30
echo "=== last 40 lines ==="
tail -40 "$LOG"
