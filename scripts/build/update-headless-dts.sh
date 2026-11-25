#!/bin/bash
# Install headless dts into the kernel package and refresh its checksum
set -euo pipefail
PKG=/home/weng/pmos-build/pmaports/device/testing/linux-postmarketos-qcom-sm8250-munch
cp /mnt/f/project/pmos-munch/dts/sm8250-xiaomi-munch-headless.dts "$PKG/sm8250-xiaomi-munch.dts"
NEWSUM=$(sha512sum "$PKG/sm8250-xiaomi-munch.dts" | awk '{print $1}')
OLDSUM=$(awk '/^sha512sums=/{f=1;next} f && /^"/{f=0} f' "$PKG/APKBUILD" | awk '$2=="sm8250-xiaomi-munch.dts"{print $1}')
echo "old=$OLDSUM"
echo "new=$NEWSUM"
if [ -n "$OLDSUM" ] && [ "$OLDSUM" != "$NEWSUM" ]; then
    sed -i "s/$OLDSUM  sm8250-xiaomi-munch.dts/$NEWSUM  sm8250-xiaomi-munch.dts/" "$PKG/APKBUILD"
fi
grep -c "$NEWSUM  sm8250-xiaomi-munch.dts" "$PKG/APKBUILD" && echo "sum updated"
grep -n "board-id\|Redmi K40S\|uart12" "$PKG/sm8250-xiaomi-munch.dts" | head -5
wc -l "$PKG/sm8250-xiaomi-munch.dts"
