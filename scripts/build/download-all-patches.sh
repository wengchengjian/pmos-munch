#!/bin/bash
set -u
export https_proxy=http://127.0.0.1:7897 http_proxy=http://127.0.0.1:7897
R=https://raw.githubusercontent.com/ShouChenICU/SteamOSforAlioth/main/external-and-mods/kernel-sm8250/patches
D=/mnt/f/project/pmos-munch/los-src/steamos/patches
mkdir -p "$D"; cd "$D"
# list all patch names from saved tree
grep "kernel-sm8250/patches/.*\.patch" /mnt/f/project/pmos-munch/los-src/steamos/paths.txt | sed 's|.*patches/||' | sort > /tmp/allpatches.lst
cat /tmp/allpatches.lst | head -40
echo "total: $(wc -l < /tmp/allpatches.lst)"
echo
echo "=== download all ==="
while read -r p; do
	[ -s "$p" ] && continue
	curl -s --max-time 60 "$R/$p" -o "$p"
	printf "%-70s %s\n" "$p" "$(stat -c %s "$p" 2>/dev/null)"
done < /tmp/allpatches.lst
