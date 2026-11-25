#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.100
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"
echo "== fresh SSH login (PAM check) =="
$SSH "$H" 'whoami; echo LOGIN_OK' 2>&1 | grep -a -v "Permanently added"
echo "== tools =="
$SSH "$H" 'for t in git python3 pip3 gcc make vim nano htop strace lsof ncdu unzip zip tcpdump sqlite3 openssl tmux rsync curl jq tree; do printf "%-10s %s\n" "$t" "$(command -v $t || echo MISSING)"; done' 2>&1
echo "== versions =="
$SSH "$H" 'python3 -V; pip3 --version; git --version; gcc --version | head -1; sqlite3 --version; htop --version 2>&1 | head -1; tcpdump --version 2>&1 | head -1; openssl version' 2>&1
echo "== system =="
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "df -h / | tail -1; systemctl --failed --no-pager; systemctl is-active sshd panel-blank.service wpa_supplicant-wlan0.service wlan0-dhcp.service; ls -la /etc/pam.d/sshd 2>/dev/null"' 2>&1 | grep -a -v "Permanently added"