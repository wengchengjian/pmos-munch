#!/bin/bash
# Create linux-postmarketos-qcom-sm8250-munch (7.2.0) package for headless munch.
# dts is a plain source file (no patch), injected in prepare(). Idempotent.
set -euo pipefail
PMAPORTS=/home/weng/pmos-build/pmaports
PKG="$PMAPORTS/device/testing/linux-postmarketos-qcom-sm8250-munch"
OFFICIAL="$PMAPORTS/device/testing/linux-postmarketos-qcom-sm8250"
SRC_DTS=/home/weng/pmos-build/kernel-src/linux-6.19.6/arch/arm64/boot/dts/qcom/sm8250-xiaomi-alioth.dts

mkdir -p "$PKG"

# 1) config: copy official 7.2.0 config under munch flavor name
cp "$OFFICIAL/config-postmarketos-qcom-sm8250.aarch64" \
   "$PKG/config-postmarketos-qcom-sm8250-munch.aarch64"

# 2) dts: start from proven alioth dts (already has munch board-id/model from 0002)
cp "$SRC_DTS" "$PKG/sm8250-xiaomi-munch.dts"
# 7.2.0 base dtsi already has cpu7_opp21(3.09GHz); our SD870 3.187GHz entry becomes opp22
sed -i 's/cpu7_opp21: opp-3187200000/cpu7_opp22: opp-3187200000/' "$PKG/sm8250-xiaomi-munch.dts"

# 3) checksums
SUM_CFG=$(sha512sum "$PKG/config-postmarketos-qcom-sm8250-munch.aarch64" | awk '{print $1}')
SUM_DTS=$(sha512sum "$PKG/sm8250-xiaomi-munch.dts" | awk '{print $1}')
SUM_TAR="05df1589411d2817fecc403402f1dea2c405c5de102bf92e23089e430fc2c623702bd778fbea5b87f70ea02e9eff7f02a7de292f895d47ff40ae88dafdfbab58"

# 4) APKBUILD (quoted heredoc: no expansion)
cat > "$PKG/APKBUILD" <<'EOF'
# Reference: <https://postmarketos.org/vendorkernel>
# Based on: linux-postmarketos-qcom-sm8250 (official pmaports)
# Adaptation for Xiaomi Redmi K40S (munch), headless server use.
pkgname=linux-postmarketos-qcom-sm8250-munch
pkgver=7.2.0_git20261010
pkgrel=0
pkgdesc="Mainline kernel fork for SM8250 (Redmi K40S headless)"
arch="aarch64"
_carch="arm64"
url="https://gitlab.postmarketos.org/soc/qualcomm-sm8250/linux"
license="GPL-2.0-only"
options="!strip !check !tracedeps
	pmb:cross-native
	pmb:kconfigcheck-nftables
	pmb:kconfigcheck-community
	pmb:kconfigcheck-uefi
"
makedepends="
	bash
	bison
	clang
	elfutils-dev
	findutils
	flex
	linux-headers
	lld
	llvm
	openssl-dev
	pahole
	perl
	postmarketos-installkernel
	python3
"

# Source
_flavor="postmarketos-qcom-sm8250-munch"
_tag="sm8250-$pkgver"
_config="config-$_flavor.$arch"
source="
	$pkgname-$_tag.tar.gz::https://gitlab.postmarketos.org/soc/qualcomm-sm8250/linux/-/archive/$_tag/linux-$_tag.tar.gz
	$_config
	sm8250-xiaomi-munch.dts
"
builddir="$srcdir/linux-$_tag"

prepare() {
	default_prepare
	cp "$srcdir/config-$_flavor.$arch" .config

	# inject munch dts and register it (idempotent)
	install -Dm644 "$srcdir/sm8250-xiaomi-munch.dts" \
		arch/arm64/boot/dts/qcom/sm8250-xiaomi-munch.dts
	grep -q "sm8250-xiaomi-munch.dtb" arch/arm64/boot/dts/qcom/Makefile || \
		echo 'dtb-$(CONFIG_ARCH_QCOM)	+= sm8250-xiaomi-munch.dtb' >> \
			arch/arm64/boot/dts/qcom/Makefile
}

build() {
	unset LDFLAGS
	make ARCH="$_carch" LLVM=1 \
		KBUILD_BUILD_VERSION="$((pkgrel + 1 ))-$_flavor"
}

package() {
	mkdir -p "$pkgdir"/boot

	if [ -e "$builddir/arch/$_carch/boot/vmlinuz.efi" ]; then
		# ZBOOT EFI decompressor for EFI booting
		install -Dm644 "$builddir/arch/$_carch/boot/vmlinuz.efi" \
			"$pkgdir/boot/linux.efi"

		# Old GZIP'd kernel image for boot.img compatibility
		install -Dm644 "$builddir/arch/$_carch/boot/vmlinuz" \
			"$pkgdir/boot/vmlinuz"
	else
		echo "WARNING: CONFIG_ZBOOT not enabled!"
		install -Dm644 "$builddir/arch/$_carch/boot/Image.gz" \
			"$pkgdir/boot/vmlinuz"
	fi

	make modules_install dtbs_install \
		ARCH="$_carch" \
		LLVM=1 \
		INSTALL_PATH="$pkgdir"/boot/ \
		INSTALL_MOD_PATH="$pkgdir"/usr \
		INSTALL_MOD_STRIP=1 \
		INSTALL_DTBS_PATH="$pkgdir/boot/dtbs"
	rm -f "$pkgdir"/usr/lib/modules/*/build "$pkgdir"/usr/lib/modules/*/source

	install -D "$builddir"/include/config/kernel.release \
		"$pkgdir"/usr/share/kernel/$_flavor/kernel.release
}
EOF

# 5) append checksums
cat >> "$PKG/APKBUILD" <<EOF

sha512sums="
$SUM_TAR  linux-postmarketos-qcom-sm8250-munch-sm8250-7.2.0_git20261010.tar.gz
$SUM_CFG  config-postmarketos-qcom-sm8250-munch.aarch64
$SUM_DTS  sm8250-xiaomi-munch.dts
"
EOF

echo "=== package created ==="
ls -la "$PKG"
echo
echo "=== dts sanity ==="
grep -n "qcom,board-id\|Redmi K40S\|xiaomi,munch\|cpu7_opp22" "$PKG/sm8250-xiaomi-munch.dts"
echo
echo "=== sums ==="
tail -6 "$PKG/APKBUILD"
