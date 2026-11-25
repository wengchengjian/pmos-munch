#!/bin/bash
# Build FAT32 userdata image for munch UEFI boot:
#   /EFI/BOOT/BOOTAA64.EFI  = GRUB standalone (arm64-efi)
#   /boot/{vmlinuz-pmos,initramfs.gz,dtb.bin}
#   /rootfs.img             = ext4 root filesystem (loop-mounted by initramfs hook)
set -euo pipefail
P=/mnt/f/project/pmos-munch
W=$P/work/fatbuild
OUT=$P/out
G=$P/edk2/grub-arm64-efi
SRCIMG=$OUT/pmos-uefi-userdata.img
FATIMG=$OUT/pmos-fat-userdata.img

mkdir -p "$W"
cd "$W"

echo "== 1. extract boot payloads from existing userdata image =="
debugfs -R "dump /boot/vmlinuz-pmos $W/vmlinuz" "$SRCIMG" 2>/dev/null
debugfs -R "dump /boot/initramfs.gz $W/initramfs.gz" "$SRCIMG" 2>/dev/null
debugfs -R "dump /boot/dtb.bin $W/dtb.bin" "$SRCIMG" 2>/dev/null
ls -la "$W/vmlinuz" "$W/initramfs.gz" "$W/dtb.bin"

echo "== 2. copy rootfs =="
cp --sparse=always "$OUT/root-debug.img" "$W/rootfs.img"
ROOTUUID=$(tune2fs -l "$W/rootfs.img" | awk '/Filesystem UUID/{print $3}')
echo "rootfs UUID: $ROOTUUID"
[ -n "$ROOTUUID" ] || { echo "no rootfs UUID"; exit 1; }

echo "== 3. patch rootfs (fstab + sshd.pam symlink) =="
sudo -n bash -c '
set -e
W=/mnt/f/project/pmos-munch/work/fatbuild
M=/mnt/pmosroot-edit
mkdir -p $M
mount -o loop $W/rootfs.img $M
sed -i "s|^UUID=.* /boot ext2.*|LABEL=PMOSBOOT /boot vfat defaults 0 0|" $M/etc/fstab
cat $M/etc/fstab
if [ ! -e $M/usr/sbin/sshd.pam ]; then
	ln -s ../bin/sshd.pam $M/usr/sbin/sshd.pam
fi
ls -la $M/usr/sbin/sshd.pam
echo "telnetd target: $(readlink -f $M/usr/sbin/telnetd 2>&1)"
test -e $M/usr/sbin/telnetd && echo "telnetd link OK" || echo "telnetd MISSING"
umount $M
'

echo "== 4. patch initramfs (add loop-root hook) =="
sudo -n bash "$P/patch-initramfs.sh"
chmod 644 "$W/initramfs-fat.gz"
ls -la "$W/initramfs-fat.gz"

echo "== 5. write grub.cfg =="
CFG=$W/grub.cfg
cat > "$CFG" <<EOF
set timeout=10
set default=0

menuentry 'postmarketOS (linux 7.2 mainline)' {
    search --no-floppy --label PMOSBOOT --set=root
    devicetree /boot/dtb.bin
    linux /boot/vmlinuz-pmos quiet loglevel=4 pmos_root_uuid=$ROOTUUID pmos_rootfsopts=defaults
    initrd /boot/initramfs.gz
}

menuentry 'postmarketOS (debug shell)' {
    search --no-floppy --label PMOSBOOT --set=root
    devicetree /boot/dtb.bin
    linux /boot/vmlinuz-pmos loglevel=7 pmos.debug-shell=1 pmos_root_uuid=$ROOTUUID
    initrd /boot/initramfs.gz
}
EOF
cat "$CFG"

echo "== 6. build GRUB standalone EFI =="
MODS="normal linux fdt fat ext2 part_gpt part_msdos search search_label search_fs_uuid search_fs_file echo test ls cat configfile boot"
grub-mkstandalone \
    --format=arm64-efi \
    --directory="$G" \
    --modules="$MODS" \
    --output="$W/BOOTAA64.EFI" \
    "boot/grub/grub.cfg=$CFG"
file "$W/BOOTAA64.EFI"
ls -la "$W/BOOTAA64.EFI"

echo "== 7. make FAT32 image =="
rm -f "$FATIMG"
truncate -s 1536M "$FATIMG"
mkfs.vfat -F 32 -n PMOSBOOT -i 5A1B2C3D -S 4096 "$FATIMG"

echo "== 8. populate FAT32 image =="
export MTOOLS_SKIP_CHECK=1
mmd -i "$FATIMG" ::/EFI
mmd -i "$FATIMG" ::/EFI/BOOT
mmd -i "$FATIMG" ::/boot
mcopy -i "$FATIMG" "$W/BOOTAA64.EFI" ::/EFI/BOOT/BOOTAA64.EFI
mcopy -i "$FATIMG" "$CFG" ::/EFI/BOOT/grub.cfg
mcopy -i "$FATIMG" "$W/vmlinuz" ::/boot/vmlinuz-pmos
mcopy -i "$FATIMG" "$W/initramfs-fat.gz" ::/boot/initramfs.gz
mcopy -i "$FATIMG" "$W/dtb.bin" ::/boot/dtb.bin
mcopy -i "$FATIMG" "$W/rootfs.img" ::/rootfs.img

echo "== 9. verify =="
fsck.vfat -n "$FATIMG"
mdir -i "$FATIMG" ::/
mdir -i "$FATIMG" ::/EFI/BOOT
mdir -i "$FATIMG" ::/boot
ls -la "$FATIMG"
echo "DONE: $FATIMG"
