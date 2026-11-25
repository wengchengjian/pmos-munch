#!/bin/bash
# Export images to /tmp/postmarketOS-export and copy to F:\project\pmos-munch\out
# NOTE: export dir contains symlinks into chroots; must dereference (cp -L).
set -eo pipefail
cd ~/pmos-build
. .venv/bin/activate
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
START=$(date +%s)
PROGRESS=/mnt/f/project/pmos-munch/logs/export-progress.log
: > "$PROGRESS"
say() { local s=$(( $(date +%s) - START )); local m; m="[$(printf '%02d:%02d:%02d' $((s/3600)) $((s%3600/60)) $((s%60)))] $*"; echo "$m"; echo "$m" >> "$PROGRESS"; }

say "export started"
pmbootstrap export
OUT=/mnt/f/project/pmos-munch/out
# 不要 rm -rf $OUT：out/ 里还有 pmos-fat-userdata.img 等交付物
mkdir -p "$OUT"
for f in boot.img xiaomi-munch-boot.img xiaomi-munch-root.img; do
    if [ -e "/tmp/postmarketOS-export/$f" ]; then
        sudo cp -L "/tmp/postmarketOS-export/$f" "$OUT/$f"
        sudo chown weng:weng "$OUT/$f"
    fi
done
if [ -e /tmp/postmarketOS-export/dtbs ]; then
    sudo cp -rL /tmp/postmarketOS-export/dtbs "$OUT/dtbs"
    sudo chown -R weng:weng "$OUT/dtbs"
fi
say "exported files:"
ls -la "$OUT" | sed 's/^/  /' | tee -a "$PROGRESS"
say "export done"
