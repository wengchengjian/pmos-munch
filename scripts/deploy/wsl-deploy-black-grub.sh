#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.103
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"
W=/mnt/f/project/pmos-munch/work/blackgrub
echo "== upload =="
$SSH "$H" 'cat > /tmp/BOOTAA64.EFI.new' < "$W/BOOTAA64.EFI" || exit 1
$SSH "$H" 'cat > /tmp/grub.cfg.new' < "$W/grub.cfg" || exit 1
echo "== install =="
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
set -e
cp /boot/EFI/BOOT/BOOTAA64.EFI /boot/EFI/BOOT/BOOTAA64.EFI.bak-black
cp /tmp/BOOTAA64.EFI.new /boot/EFI/BOOT/BOOTAA64.EFI
cp /tmp/grub.cfg.new /boot/EFI/BOOT/grub.cfg
sync
ls -la /boot/EFI/BOOT/
"' || exit 1
echo "== reboot =="
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" reboot' 2>/dev/null || true
echo "reboot sent"
