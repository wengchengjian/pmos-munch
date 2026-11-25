#!/bin/bash
set -u
K=/home/weng/pmos-build/kernel-src/linux-sm8250-7.2.0_git20261010
PKG=/home/weng/pmos-build/pmaports/device/testing/linux-postmarketos-qcom-sm8250-munch
SRC=/mnt/f/project/pmos-munch/dts/refs/munch.dts
cp "$SRC" "$PKG/sm8250-xiaomi-munch.dts"
cp "$SRC" "$K/arch/arm64/boot/dts/qcom/sm8250-xiaomi-munch.dts"
NEW=$(sha512sum "$PKG/sm8250-xiaomi-munch.dts" | awk '{print $1}')
# replace the dts checksum line in APKBUILD
sed -i -E "s|^[0-9a-f]{128}  sm8250-xiaomi-munch\.dts$|$NEW  sm8250-xiaomi-munch.dts|" "$PKG/APKBUILD"
echo "new dts sha512: $NEW"
grep "sm8250-xiaomi-munch.dts" "$PKG/APKBUILD"
echo
echo "=== compile test (cpp+dtc) ==="
cd "$K/arch/arm64/boot/dts/qcom" || exit 1
cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
	-I "$K/include" -I "$K/arch/arm64/boot/dts" -I "$K/arch/arm64/boot/dts/qcom" \
	sm8250-xiaomi-munch.dts -o /tmp/munch.pp.dts 2> /tmp/munch.cpp.err
CPP_RC=$?
echo "cpp rc=$CPP_RC"
head -20 /tmp/munch.cpp.err
if [ $CPP_RC -eq 0 ]; then
	dtc -I dts -O dtb -o /tmp/munch.dtb /tmp/munch.pp.dts 2> /tmp/munch.dtc.err
	DTC_RC=$?
	echo "dtc rc=$DTC_RC"
	head -30 /tmp/munch.dtc.err
	ls -la /tmp/munch.dtb 2>/dev/null
	# verify key nodes in compiled dtb
	if [ $DTC_RC -eq 0 ]; then
		dtc -I dtb -O dts /tmp/munch.dtb 2>/dev/null | grep -nE "ami667|ams667|ft8756|mdss_dsi0|spi4|vreg_l11a" | head -20
	fi
fi
