#!/bin/bash
# Verify headless dtb from the built apk: board-id, model, node inventory
set -uo pipefail
PKGS=/home/weng/.local/var/pmbootstrap/packages/edge/aarch64
APKFILE=$(ls -t "$PKGS"/linux-postmarketos-qcom-sm8250-munch-*.apk 2>/dev/null | head -1)
[ -n "$APKFILE" ] || { echo "FATAL: no kernel apk"; exit 1; }
echo "apk: $(basename "$APKFILE")"
WORK=/tmp/verify-headless
rm -rf "$WORK"; mkdir -p "$WORK"
DTB=$(tar -tzf "$APKFILE" 2>/dev/null | grep -E "sm8250-xiaomi-munch\.dtb$" | head -1)
echo "dtb in apk: $DTB"
tar -xzf "$APKFILE" -C "$WORK" "$DTB" 2>/dev/null
DTBFILE=$(find "$WORK" -name '*.dtb' | head -1)
dtc -I dtb -O dts -q "$DTBFILE" -o "$WORK/out.dts"
echo
echo "=== board identity ==="
grep -E 'model = "|qcom,board-id|qcom,msm-id' "$WORK/out.dts" | head -4
echo
echo "=== kept nodes (expect >0) ==="
for pat in uart12 'wifi@0' ufs_mem_hc usb_1 pm8150b_charger pm8150b_fg qca6390 quad-spi; do
    printf "%-20s %s\n" "$pat" "$(grep -c "$pat" "$WORK/out.dts" || true)"
done
echo
echo "=== cut nodes (expect 0 or absent) ==="
for pat in cs35l41 touchscreen 'xiaomi,alioth-ams667xx01' 'qcom,sm8250-sndcard' csiphy imx582 venus; do
    printf "%-30s %s\n" "$pat" "$(grep -c "$pat" "$WORK/out.dts" || true)"
done
echo
echo "=== enabled status count ==="
grep -c 'status = "okay"' "$WORK/out.dts" || true
echo "=== dtb size / lines ==="
ls -la "$DTBFILE"; wc -l "$WORK/out.dts"
echo
if grep -q "board-id = <0x32" "$WORK/out.dts" && grep -q "Redmi K40S" "$WORK/out.dts"; then
    echo "HEADLESS_DTB_VERIFIED"
else
    echo "HEADLESS_DTB_FAILED"
    exit 1
fi
