#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.103
HUSB=user@172.16.42.1
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=4 -o ServerAliveInterval=15"
echo "== reboot =="
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" reboot' 2>/dev/null || true
sleep 8
echo "== wait for ssh =="
OK=0
for i in $(seq 1 48); do
  if $SSH "$H" 'true' >/dev/null 2>&1; then OK=1; break; fi
  sleep 5
done
if [ "$OK" != 1 ]; then
  echo "WiFi SSH not up yet; trying USB 172.16.42.1"
  for i in $(seq 1 12); do
    if $SSH "$HUSB" 'true' >/dev/null 2>&1; then H=$HUSB; OK=1; break; fi
    sleep 5
  done
fi
if [ "$OK" != 1 ]; then
  echo "FAILED: no SSH on WiFi or USB"
  exit 1
fi
echo "== connected: $H =="
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
echo === root ===
findmnt -no SOURCE,FSTYPE,SIZE / 2>/dev/null || cat /proc/mounts | grep \" / \"
df -h / /boot
echo === dmesg loop ===
dmesg | grep -E \"loop-root|EXT4-fs \\(loop\" | tail -12
echo === services ===
systemctl --failed --no-pager
systemctl is-active panel-blank.service wpa_supplicant-wlan0.service wlan0-dhcp.service sshd.service
echo === net ===
ip -4 addr show wlan0 2>/dev/null | grep inet
echo === battery ===
/usr/local/bin/battery 2>/dev/null || cat /sys/class/power_supply/qcom-battery/capacity
echo === old rootfs.img ===
ls -lh /boot/rootfs.img
"' 2>&1 | grep -a -v "Permanently added"