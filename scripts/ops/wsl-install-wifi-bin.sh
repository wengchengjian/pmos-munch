#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@172.16.42.1
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"
echo "== upload =="
$SSH "$H" 'cat > /tmp/wifi-bin.tar.gz' < /mnt/f/project/pmos-munch/out/wifi-pkgs/wifi-bin.tar.gz || exit 1
echo "== extract =="
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "tar -xzf /tmp/wifi-bin.tar.gz -C / && chmod +x /usr/local/wifi/bin/* && ls -la /usr/local/wifi/bin /usr/local/wifi/lib | head -8"' 2>&1 | tail -8
echo "== test wpa_supplicant =="
$SSH "$H" 'LD_LIBRARY_PATH=/usr/local/wifi/lib /usr/local/wifi/bin/wpa_supplicant -v 2>&1 | head -3'
echo "== test iw =="
$SSH "$H" 'LD_LIBRARY_PATH=/usr/local/wifi/lib /usr/local/wifi/bin/iw dev 2>&1 | head -10'
