#!/bin/bash
set -u
K=/home/weng/pmos-build/kernel-src/linux-sm8250-7.2.0_git20261010
P=/mnt/f/project/pmos-munch/los-src/steamos/patches
LOG=/mnt/f/project/pmos-munch/out/patch-apply.log
mkdir -p /mnt/f/project/pmos-munch/out
cd "$K" || exit 1
: > "$LOG"
ok=0; fail=0
for f in $(ls "$P"/*.patch | sort); do
	b=$(basename "$f")
	# skip already-applied (reverse-check)
	if patch -p1 --dry-run --reverse -f -s < "$f" >/dev/null 2>&1; then
		echo "SKIP(already applied) $b" | tee -a "$LOG"; continue
	fi
	if patch -p1 --forward -f --no-backup-if-mismatch < "$f" > /tmp/p.out 2>&1; then
		rc=$?
		rej=$(grep -c "FAILED\|Reversed\|hunk" /tmp/p.out || true)
		echo "OK   $b  (fuzz/rejects=$rej)" | tee -a "$LOG"
		ok=$((ok+1))
	else
		echo "FAIL $b" | tee -a "$LOG"
		cat /tmp/p.out >> "$LOG"
		fail=$((fail+1))
	fi
done
echo "=== result: ok=$ok fail=$fail ===" | tee -a "$LOG"
echo
echo "=== .rej files ==="
find "$K" -name '*.rej' -newer "$P/0001-drm-msm-bound-the-fence-wait-in-vm-close.patch" 2>/dev/null | head -20
echo
echo "=== added drivers? ==="
ls -la drivers/gpu/drm/panel/panel-samsung-ams667xx01.c drivers/input/touchscreen/ft8756.c drivers/input/touchscreen/sitronix_st7123.c 2>/dev/null
