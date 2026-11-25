#!/bin/bash
# Give the phone internet via reverse SSH tunnel, then install WiFi tools (as root).
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@172.16.42.1
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"
SUDO='echo CHANGE_ME_PASSWORD | sudo -S -p ""'
echo "== start reverse tunnel =="
$SSH -f -N -o ExitOnForwardFailure=yes -R 7897:127.0.0.1:7897 "$H" && echo "tunnel up" || { echo "TUNNEL FAILED"; exit 1; }
sleep 1
echo "== apk update (https via proxy) =="
$SSH "$H" "$SUDO env http_proxy=http://127.0.0.1:7897 https_proxy=http://127.0.0.1:7897 apk update 2>&1 | tail -6"
echo "== apk add iw wpa_supplicant dhcpcd =="
$SSH "$H" "$SUDO env http_proxy=http://127.0.0.1:7897 https_proxy=http://127.0.0.1:7897 apk add iw wpa_supplicant dhcpcd 2>&1 | tail -10"
echo "== verify =="
$SSH "$H" 'which iw wpa_supplicant dhcpcd 2>/dev/null; df -h / | tail -1'
echo "== stop tunnel =="
pkill -f "ssh -f -N -o ExitOnForwardFailure=yes -R 7897" 2>/dev/null
echo done
