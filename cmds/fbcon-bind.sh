#!/bin/sh
echo "=== vtconsole bind states ==="
for v in /sys/class/vtconsole/vtcon0 /sys/class/vtconsole/vtcon1; do
	[ -d "$v" ] || continue
	echo "$v: name=$(cat $v/name 2>/dev/null) bind=$(cat $v/bind 2>/dev/null)"
done
echo "=== fb0 console attr ==="
cat /sys/class/graphics/fb0/console 2>/dev/null
echo "=== /proc/iomem 9c000000 ==="
grep -i "9c000000\|9c0\|simple" /proc/iomem | head -5
echo "=== force bind fbcon if needed ==="
[ "$(cat /sys/class/vtconsole/vtcon1/bind 2>/dev/null)" = "0" ] && echo 1 > /sys/class/vtconsole/vtcon1/bind && echo "bound vtcon1"
echo "=== clear fb0 (zeros) ==="
dd if=/dev/zero of=/dev/fb0 bs=4096 count=2532 conv=notrunc 2>&1 | tail -1
echo "=== print marker to tty1 ==="
echo "SCREEN TEST 123 - fbcon marker" > /dev/tty1
sleep 1
echo "SCREEN_TEST_DONE"
