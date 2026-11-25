#!/bin/bash
# Fix duplicate cpu7 OPP label for 7.2.0 and recompile the dtb
set -euo pipefail
TREE=/home/weng/pmos-build/kernel-src/linux-sm8250-7.2.0_git20261010
DTS="$TREE/arch/arm64/boot/dts/qcom/sm8250-xiaomi-alioth.dts"

sed -i 's/cpu7_opp21: opp-3187200000/cpu7_opp22: opp-3187200000/' "$DTS"
echo "=== dts opp lines ==="
grep -n "3167200000\|3187200000\|cpu7_opp2" "$DTS" || true

echo "=== recompile dtb ==="
make -C "$TREE" ARCH=arm64 -j16 qcom/sm8250-xiaomi-alioth.dtb 2>&1 | tail -25
ls -la "$TREE/arch/arm64/boot/dts/qcom/sm8250-xiaomi-alioth.dtb" 2>/dev/null && echo DTB_BUILT || echo DTB_MISSING
