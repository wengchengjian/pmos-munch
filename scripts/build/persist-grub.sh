#!/bin/bash
# Persist grub arm64 modules into the project dir (survives WSL /tmp wipes)
set -euo pipefail
export https_proxy=http://127.0.0.1:7897
export http_proxy=http://127.0.0.1:7897
DEST=/mnt/f/project/pmos-munch/edk2/grub-arm64-efi
WORK=/tmp/grub-persist
mkdir -p "$DEST"
rm -rf "$WORK"
mkdir -p "$WORK"
cd "$WORK"
curl -sSL -o grub-arm.deb "http://ports.ubuntu.com/ubuntu-ports/pool/main/g/grub2-unsigned/grub-efi-arm64-bin_2.06-2ubuntu7_arm64.deb"
dpkg -x grub-arm.deb extracted
cp -a extracted/usr/lib/grub/arm64-efi/. "$DEST/"
echo "persisted modules: $(ls "$DEST"/*.mod | wc -l)"
ls "$DEST" | grep -E "^(fdt|linux|ext2|normal|search_fs_uuid|part_gpt)\.mod"
