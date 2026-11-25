#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=4 -o ServerAliveInterval=10"
echo "== reboot =="
$SSH user@192.168.0.100 'echo CHANGE_ME_PASSWORD | sudo -S -p "" reboot' 2>/dev/null || true
sleep 10
H=""
for i in $(seq 1 48); do
  for cand in user@192.168.0.100 user@192.168.0.103; do
    if $SSH "$cand" 'true' >/dev/null 2>&1; then H="$cand"; break 2; fi
  done
  sleep 5
done
if [ -z "$H" ]; then echo "FAILED: no SSH"; exit 1; fi
echo "connected: $H"
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
echo == services ==
for s in containerd docker redis postgresql sshd panel-blank wpa_supplicant-wlan0 wlan0-dhcp systemd-resolved; do printf \"%-28s \" \$s; systemctl is-active \$s; done
echo == ip/dns ==
ip -4 addr show wlan0 | grep inet
resolvectl status 2>/dev/null | grep -E \"Current DNS|DNS Servers\" | head -3
echo == docker cached run ==
timeout 60 docker run --rm hello-world 2>&1 | grep -E \"Hello from Docker|ERROR\" | head -3
echo == npm ==
npm view express version 2>&1 | tail -1
echo == pip ==
rm -rf /tmp/pip-test2; pip3 download --no-deps -d /tmp/pip-test2 six 2>&1 | grep -E \"Looking in indexes|Saved\" | head -2
echo == apk ==
apk update 2>&1 | tail -2
echo == df ==
df -h / | tail -1
"' 2>&1 | grep -a -v "Permanently added"