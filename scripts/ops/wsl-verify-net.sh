#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6"
for H in user@192.168.0.100 user@192.168.0.103; do
  echo "== $H =="
  $SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
hostname
ip -4 addr show wlan0 | grep inet
ip route | head -3
ping -c 2 -W 3 223.5.5.5 | tail -2
ping -c 2 -W 3 192.168.0.1 | tail -2
df -h / | tail -1
"' 2>&1 | grep -a -v "Permanently added" && break
done