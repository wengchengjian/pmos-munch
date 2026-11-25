#!/bin/bash
# Build linux-postmarketos-qcom-sm8250-munch (7.2.0) with progress.
# Uses --src persistent tree; cleans host build artifacts first (mrproper),
# re-seeds distfiles tarball for future non-src builds.
set -eo pipefail
cd ~/pmos-build
. .venv/bin/activate
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY

TREE=/home/weng/pmos-build/kernel-src/linux-sm8250-7.2.0_git20261010
LOG=/home/weng/.local/var/pmbootstrap/log.txt
PROGRESS=/mnt/f/project/pmos-munch/logs/build720-progress.log
OUT=/tmp/pmb-build720.out
PKG=linux-postmarketos-qcom-sm8250-munch

: > "$PROGRESS"
START=$(date +%s)
elapsed() { local s=$(( $(date +%s) - START )); printf '%02d:%02d:%02d' $((s/3600)) $((s%3600/60)) $((s%60)); }
say() { local m; m="[$(elapsed)] $*"; echo "$m"; echo "$m" >> "$PROGRESS"; }

# 0) rsync in pmbootstrap --src uses the tree's .gitignore as an exclude list,
#    but kernel .gitignore has git-style "!negation" patterns that rsync treats
#    literally, silently dropping needed sources (e.g. kernel/time/timeconst.bc
#    excluded by "*.bc", negation not understood). Disable it.
if [ -f "$TREE/.gitignore" ]; then
    mv "$TREE/.gitignore" "$TREE/.gitignore.disabled-for-pmb-src"
    echo "disabled kernel .gitignore for pmb --src rsync"
fi

# 1) seed distfiles with correctly-named tarball (for non-src builds later)
D=/home/weng/.local/var/pmbootstrap/chroot_native/var/cache/distfiles
SRCTAR="$D/linux-postmarketos-qcom-sm8250-munch-sm8250-7.2.0_git20261010.tar.gz"
if [ ! -f "$SRCTAR" ]; then
    sudo cp /home/weng/pmos-build/kernel-src/linux-7.2.0_git20261010.tar.gz "$SRCTAR"
    sudo chown 12345:12345 "$SRCTAR"
    echo "distfiles seeded"
fi

# 2) clean host build artifacts from the tree (keeps dts + Makefile edits)
say "mrproper: cleaning host artifacts from 7.2.0 tree"
make -C "$TREE" ARCH=arm64 mrproper >/dev/null 2>&1 || true

say "7.2.0 kernel build started (pkg=$PKG, mode=--src, cold compile expected)"
OFF=$(stat -c %s "$LOG" 2>/dev/null || echo 0); OFF=${OFF:-0}
pmbootstrap -y build --lax --src "$TREE" "$PKG" > "$OUT" 2>&1 &
PID=$!
LASTCC=0
while kill -0 "$PID" 2>/dev/null; do
    sleep 15
    CUR=$(tail -c +$((OFF + 1)) "$LOG" 2>/dev/null)
    CC=$(printf '%s' "$CUR" | grep -ac "  CC " || true); CC=${CC:-0}
    DELTA=$((CC - LASTCC)); LASTCC=$CC
    PCT=$(( CC * 80 / 5424 )); [ "$PCT" -gt 80 ] && PCT=80
    PHASE=""
    printf '%s' "$CUR" | grep -aq "LD      vmlinux" && { PHASE="vmlinux link"; PCT=78; }
    printf '%s' "$CUR" | grep -aq "DTC " && { PHASE="dtbs"; PCT=82; }
    printf '%s' "$CUR" | grep -aq "INSTALL .*pkg/linux" && { PHASE="package"; PCT=90; }
    printf '%s' "$CUR" | grep -aq "Done!" && { PHASE="done"; PCT=99; }
    TAIL=$(printf '%s' "$CUR" | grep -av "^\s*$" | tail -1 | cut -c1-48 || true)
    say "${PCT}% | CC=$CC (+${DELTA}/15s) | ${PHASE:-compile} | ${TAIL}"
done
wait "$PID"; RC=$?
say "7.2.0 build finished rc=$RC"
tail -25 "$OUT" | sed 's/^/  /' >> "$PROGRESS"
cat "$PROGRESS"
[ "$RC" -eq 0 ] && echo "KERNEL720_BUILD_OK" || echo "KERNEL720_BUILD_FAILED rc=$RC"
exit "$RC"
