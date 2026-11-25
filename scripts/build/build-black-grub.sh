#!/bin/bash
set -u
P=/mnt/f/project/pmos-munch
G=$P/edk2/grub-arm64-efi
W=$P/work/blackgrub
MODS="normal linux fdt fat ext2 part_gpt part_msdos search search_label search_fs_uuid search_fs_file echo test ls cat configfile boot serial terminal"
UUID=687be8df-d76e-40ac-b251-8a4032ad04f3
rm -rf "$W"; mkdir -p "$W"; cd "$W"

cat > grub.cfg <<'EOF'
set timeout=3
set default=0

menuentry 'postmarketOS (headless)' {
    search --no-floppy --label PMOSBOOT --set=root
    devicetree /boot/dtb.bin
    linux /boot/vmlinuz-pmos quiet loglevel=4 pmos_root_uuid=@UUID@ pmos_rootfsopts=defaults fbcon=map:1
    initrd /boot/initramfs.gz
    clear
}
EOF

cat > grub-test.cfg <<'EOF'
set timeout=3
set default=0
terminal_output serial console

menuentry 'postmarketOS (headless)' {
    echo MARK_MENU
    search --no-floppy --label PMOSBOOT --set=root
    echo MARK_ROOT_$root
    devicetree /boot/dtb.bin
    echo MARK_DTB
    linux /boot/vmlinuz-pmos quiet loglevel=4 pmos_root_uuid=@UUID@ pmos_rootfsopts=defaults fbcon=map:1
    echo MARK_LINUX
    initrd /boot/initramfs.gz
    echo MARK_INITRD
    clear
    echo MARK_CLEAR
}
EOF

sed -i "s/@UUID@/$UUID/g" grub.cfg grub-test.cfg
grub-mkstandalone --format=arm64-efi --directory="$G" --modules="$MODS" --output=BOOTAA64.EFI "boot/grub/grub.cfg=$W/grub.cfg" || exit 1
grub-mkstandalone --format=arm64-efi --directory="$G" --modules="$MODS" --output=BOOTAA64-TEST.EFI "boot/grub/grub.cfg=$W/grub-test.cfg" || exit 1
ls -la BOOTAA64.EFI BOOTAA64-TEST.EFI
echo "=== production cfg ==="; cat grub.cfg
