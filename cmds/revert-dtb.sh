#!/bin/sh
# Revert dtb to backup and reboot
set -e
cp /boot/boot/dtb.bin.bak /boot/boot/dtb.bin
echo reverted
sync
systemctl reboot
