#!/bin/bash
# Assemble postmarketOS images with live output + elapsed time.
set -eo pipefail
cd ~/pmos-build
. .venv/bin/activate
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
START=$(date +%s)
PROGRESS=/mnt/f/project/pmos-munch/logs/install-progress.log
: > "$PROGRESS"
say() { local s=$(( $(date +%s) - START )); local m; m="[$(printf '%02d:%02d:%02d' $((s/3600)) $((s%3600/60)) $((s%60)))] $*"; echo "$m"; echo "$m" >> "$PROGRESS"; }
say "install started (device=xiaomi-munch, ui=none, --split)"
set +e
pmbootstrap -y install --password CHANGE_ME_PASSWORD --split 2>&1 | tee -a "$PROGRESS"
RC=${PIPESTATUS[0]}
set -e
say "install finished rc=$RC"
exit "$RC"
