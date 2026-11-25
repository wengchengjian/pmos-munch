#!/bin/sh
echo "=== dmesg simpledrm (acquire line should be gone) ==="
dmesg 2>/dev/null | grep -iE "simpledrm|simple-framebuffer" | head -4
echo "=== /dev/mem ==="
ls -la /dev/mem
echo "=== fill 0x9C000000..0x9E4000 with zeros via /dev/mem ==="
dd if=/dev/zero of=/dev/mem bs=4096 seek=638976 count=2532 conv=notrunc 2>&1 | tail -2
echo "dd_rc=$?"
sync
echo "=== readback ==="
dd if=/dev/mem bs=4096 skip=638976 count=1 2>/dev/null | hexdump -C | head -2
echo MEMTEST_DONE
