#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.103
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"
B=/mnt/f/project/pmos-munch/out/backup-20261125-133425
echo "== stat =="
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" stat -c "%n %s" /boot/boot/initramfs.gz /boot/EFI/BOOT/grub.cfg /boot/boot/vmlinuz-pmos /boot/boot/dtb.bin' 2>&1
echo "== cat initramfs size =="
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "cat /boot/boot/initramfs.gz" ' 2>/dev/null | wc -c
echo "== cat grub cfg =="
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "cat /boot/EFI/BOOT/grub.cfg"' 2>/dev/null
echo "== now write files =="
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "cat /boot/boot/initramfs.gz"' > "$B/initramfs.gz" 2>/dev/null
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "cat /boot/EFI/BOOT/grub.cfg"' > "$B/grub.cfg" 2>/dev/null
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "cat /boot/boot/vmlinuz-pmos"' > "$B/vmlinuz-pmos" 2>/dev/null
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "cat /boot/boot/dtb.bin"' > "$B/dtb.bin" 2>/dev/null
ls -la "$B"