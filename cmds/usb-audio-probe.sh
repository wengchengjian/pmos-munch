#!/bin/sh
# Verify USB host role switch and sound module availability on phone
echo "=== modules present? ==="
ls /lib/modules/7.2.0/kernel/sound/usb/ 2>/dev/null | head
ls /lib/modules/7.2.0/kernel/sound/soc/codecs/ 2>/dev/null | grep -iE "wcd938x|wsa" | head
ls /lib/modules/7.2.0/kernel/drivers/usb/host/ 2>/dev/null | head -5
echo
echo "=== try switch to host ==="
echo host > /sys/class/typec/port0/data_role 2>&1
echo "role write rc=$?"
sleep 2
cat /sys/class/typec/port0/data_role
echo "=== usb buses ==="
ls /sys/bus/usb/devices/ 2>/dev/null | head -8
echo "=== switch back to device ==="
echo device > /sys/class/typec/port0/data_role 2>&1
sleep 1
cat /sys/class/typec/port0/data_role
echo "=== alsa tools? ==="
which arecord aplay amixer 2>/dev/null || echo "alsa-utils missing"
echo "=== space ==="
df -h / | tail -1
