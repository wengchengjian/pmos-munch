#!/bin/sh
echo "=== chosen framebuffer node in booted DT ==="
for p in /sys/firmware/devicetree/base/chosen/framebuffer \
         /sys/firmware/devicetree/base/chosen/framebuffer@0; do
	[ -d "$p" ] || continue
	echo "node: $p"
	for f in compatible reg width height stride format; do
		[ -e "$p/$f" ] || continue
		echo -n "$f: "
		hexdump -v -e '"%d "' "$p/$f" 2>/dev/null | head -c 120
		echo
	done
done
echo
echo "=== fb0 attrs ==="
cat /sys/class/graphics/fb0/stride /sys/class/graphics/fb0/bits_per_pixel /sys/class/graphics/fb0/state 2>/dev/null
echo
echo "=== dmesg simple/drm ==="
dmesg 2>/dev/null | grep -iE "simpledrm|simple-framebuffer|fb0|drm" | head -10
echo
echo "=== reserved-memory splash? ==="
ls /proc/device-tree/reserved-memory/ 2>/dev/null | head
