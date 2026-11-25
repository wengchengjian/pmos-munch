#!/bin/bash
set -u
S=/mnt/f/project/pmos-munch/out/wifi-pkgs/stage
for b in "$S/sbin/wpa_supplicant" "$S/usr/sbin/iw"; do
	echo "--- $b"
	file "$b"
	readelf -d "$b" 2>/dev/null | grep NEEDED
done
echo "== build upload tree =="
T=/mnt/f/project/pmos-munch/out/wifi-pkgs/upload
rm -rf "$T"; mkdir -p "$T/usr/local/wifi/bin" "$T/usr/local/wifi/lib"
cp -a "$S/sbin/wpa_supplicant" "$S/sbin/wpa_cli" "$S/sbin/wpa_passphrase" "$T/usr/local/wifi/bin/"
cp -a "$S/usr/sbin/iw" "$T/usr/local/wifi/bin/"
cp -a "$S"/usr/lib/libdbus-1.so.3* "$S"/usr/lib/libnl-*.so.200* "$S"/usr/lib/libpcsclite*.so* "$T/usr/local/wifi/lib/"
ls -la "$T/usr/local/wifi/bin" "$T/usr/local/wifi/lib"
cd "$T" && tar -czf /mnt/f/project/pmos-munch/out/wifi-pkgs/wifi-bin.tar.gz usr
ls -la /mnt/f/project/pmos-munch/out/wifi-pkgs/wifi-bin.tar.gz
