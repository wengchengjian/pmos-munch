#!/bin/sh
echo "=== usb_role class ==="
ls /sys/class/usb_role/ 2>/dev/null || echo "no usb_role class"
for r in /sys/class/usb_role/*/; do
	[ -e "$r/role" ] || continue
	echo "dev: $r"
	echo "current: $(cat "$r/role" 2>/dev/null)"
	echo host > "$r/role" 2>&1 && echo "-> host OK" || echo "-> host FAILED"
	sleep 2
	echo "now: $(cat "$r/role" 2>/dev/null)"
	ls /sys/bus/usb/devices/ 2>/dev/null | head -6
	echo device > "$r/role" 2>/dev/null
	sleep 1
	echo "restored: $(cat "$r/role" 2>/dev/null)"
done
echo
echo "=== typec port0 attrs ==="
ls /sys/class/typec/port0/ 2>/dev/null | tr '\n' ' '
echo
echo "=== typec partner ==="
ls /sys/class/typec/port0-partner/ 2>/dev/null | tr '\n' ' '
echo
echo "=== usb vbus regulator module ==="
ls /lib/modules/7.2.0/kernel/drivers/regulator/ 2>/dev/null | grep -i "vbus\|usb" | head -5
echo
echo "=== dmesg typec/usb ==="
dmesg 2>/dev/null | grep -iE "typec|usb_role|dwc3|usb_phy" | tail -12
