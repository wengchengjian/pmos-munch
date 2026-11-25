#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.103
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"
echo "== backup /etc to FAT =="
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "tar -czf /boot/etc-backup-$(date +%s).tar.gz /etc /root/.ssh /home/user/.ssh 2>/dev/null; ls -la /boot/etc-backup-* | tail -2"' 2>&1 | grep -a -v "Permanently added"
echo "== empty world + install tmux =="
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
cp /etc/apk/world /etc/apk/world.bak
: > /etc/apk/world
apk add --force-overwrite tmux 2>&1 | tail -30
echo === after ===
command -v tmux; tmux -V
cat /etc/apk/world
"' 2>&1 | grep -a -v "Permanently added" | tail -40
