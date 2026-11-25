#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.103
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
echo \"== tools ==\"
for t in mkfs.ext4 tune2fs e2fsck resize2fs losetup blkid rsync sgdisk parted fsfreeze; do printf \"%-12s \" \$t; command -v \$t || echo MISSING; done
echo \"== fat volume size ==\"
stat -f -c \"bsize=%S blocks=%b bytes=%s\" /boot
echo \"== fstab ==\"
cat /etc/fstab
echo \"== root usage ==\"
du -sh /usr /var /home /etc 2>/dev/null
echo \"== loop ==\"
losetup -a
losetup --help 2>&1 | grep -E \"offset|sizelimit\" | head -4
echo \"== free space ==\"
df -h / /boot | tail -3
"' 2>&1 | grep -a -v "Permanently added"
