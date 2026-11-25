#!/bin/bash
set -u
P=/mnt/f/project/pmos-munch
W=$P/work/blackgrub
T=/tmp/testfat-black.img
LOG=$P/work/qemu-black.log
echo "== copy FAT =="
cp "$P/out/pmos-fat-userdata.img" "$T" || exit 1
echo "== inject test grub =="
mcopy -o -i "$T" "$W/BOOTAA64-TEST.EFI" ::/EFI/BOOT/BOOTAA64.EFI || exit 1
echo "== qemu =="
timeout 75 qemu-system-aarch64 \
  -machine virt -cpu cortex-a72 -m 2048 -smp 2 \
  -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
  -drive file="$T",if=virtio,format=raw \
  -nographic -no-reboot > "$LOG" 2>&1
echo "qemu rc=$?"
echo "=== markers ==="
grep -aE "MARK_|error:|GRUB|Booting|PMOSBOOT" "$LOG" | head -30
echo "=== tail ==="
tail -20 "$LOG"
rm -f "$T"
