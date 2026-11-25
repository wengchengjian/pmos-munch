#!/bin/sh
echo "=== uptime ==="
uptime
echo "=== reserved splash_region in DT ==="
ls /proc/device-tree/reserved-memory/ 2>/dev/null | grep -i splash
hexdump -v -e '"%d "' /proc/device-tree/reserved-memory/splash_region/reg 2>/dev/null | head -c 100; echo
echo "=== cmdline ==="
cat /proc/cmdline
echo "=== dmesg simpledrm ==="
dmesg 2>/dev/null | grep -iE "simpledrm|simple-framebuffer|fbcon" | head -6
echo "=== fb0 ==="
cat /sys/class/graphics/fb0/virtual_size /sys/class/graphics/fb0/stride /sys/class/graphics/fb0/state 2>/dev/null
echo "=== VT1 text (actual screen buffer) ==="
cat /dev/vcs1 2>/dev/null | tr -s ' ' | head -c 1500
echo
echo "=== getty ==="
systemctl is-active getty@tty1
