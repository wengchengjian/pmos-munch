#!/bin/bash
set -u
export https_proxy=http://127.0.0.1:7897 http_proxy=http://127.0.0.1:7897
W=/mnt/f/project/pmos-munch/out/wifi-pkgs
mkdir -p "$W/dl" "$W/stage"; cd "$W/dl"
BASE=https://mirrors.aliyun.com/alpine/edge/main/aarch64
for f in wpa_supplicant-2.11-r7.apk iw-6.17-r0.apk libnl3-3.12.0-r0.apk dbus-libs-1.16.4-r0.apk pcsc-lite-libs-2.5.2-r0.apk; do
	[ -s "$f" ] || curl -s --max-time 120 "$BASE/$f" -o "$f"
	printf "%-40s %s\n" "$f" "$(stat -c %s "$f" 2>/dev/null)"
done
echo "== extract =="
for f in *.apk; do
	tar -xzf "$f" -C "$W/stage" 2>/dev/null && echo "OK $f" || echo "FAIL $f"
done
echo "== stage contents =="
find "$W/stage" -type f -o -type l | grep -E "sbin|bin/|lib/" | head -40
echo "== NEEDED =="
for b in "$W/stage/usr/sbin/wpa_supplicant" "$W/stage/usr/bin/iw"; do
	[ -f "$b" ] && { echo "--- $b"; readelf -d "$b" 2>/dev/null | grep NEEDED; file "$b" 2>/dev/null; }
done
