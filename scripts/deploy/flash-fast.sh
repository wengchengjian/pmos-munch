#!/bin/bash
# Fast-fail flash + boot verification. Every stage has a hard timeout and
# the script always ends with SUCCESS or FAILED(reason) in <= ~4 minutes.
# Usage: bash flash-fast.sh            # flash + reboot + wait HTTP
#        bash flash-fast.sh skipflash # only reboot + wait HTTP
FB="/c/Users/wengchengjian/AppData/Local/Android/Sdk/platform-tools/fastboot.exe"
cd /f/project/pmos-munch || exit 1
MODE="${1:-}"

t0=$(date +%s)
el() { echo "$(( $(date +%s) - t0 ))s"; }

echo "[1/4] WAIT_FASTBOOT (max 60s)"
found=0
for i in $(seq 1 30); do
	if "$FB" devices 2>/dev/null | tr -d '\r' | grep -qi fastboot; then found=1; break; fi
	sleep 2
done
if [ "$found" != "1" ]; then
	echo "FAILED(stage=fastboot): no device within 60s."
	echo "ACTION: put phone into fastboot (hold Vol- + Power), then rerun."
	exit 10
fi
echo "OK fastboot (t=$(el))"

if [ "$MODE" != "skipflash" ]; then
	echo "[2/4] FLASH userdata (max 180s)"
	if ! timeout 180 "$FB" flash userdata out/pmos-fat-userdata.img 2>&1 | tail -2; then
		echo "FAILED(stage=flash): flash error/timeout"
		exit 11
	fi
else
	echo "[2/4] FLASH skipped"
fi

echo "[3/4] REBOOT"
"$FB" reboot 2>&1 | head -1 || true
echo "reboot sent (link-drop errors are normal)"

echo "[4/4] WAIT_HTTP (max 150s) http://172.16.42.1/diag.txt"
hit=0
for i in $(seq 1 75); do
	code=$(curl.exe -s -m 2 -o /dev/null -w "%{http_code}" http://172.16.42.1/diag.txt 2>/dev/null)
	if [ "$code" = "200" ]; then hit=1; break; fi
	sleep 2
done
if [ "$hit" = "1" ]; then
	echo "SUCCESS (t=$(el)): HTTP debug shell reachable"
	echo "----- diag.txt (head) -----"
	curl.exe -s -m 5 http://172.16.42.1/diag.txt 2>/dev/null | head -40
	echo "---------------------------"
	exit 0
fi

echo "FAILED(stage=http): not reachable within 150s. Evidence:"
echo "- fastboot now: $("$FB" devices 2>/dev/null | tr -d '\r' | head -1)"
NET=$(powershell.exe -NoProfile -Command "Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { \$_.InterfaceDescription -match 'NCM|RNDIS' } | Select-Object -First 1 -ExpandProperty InterfaceDescription" 2>/dev/null | tr -d '\r')
echo "- ncm adapter: ${NET:-none}"
if ping -n 2 172.16.42.1 >/dev/null 2>&1; then echo "- ping 172.16.42.1: OK"; else echo "- ping 172.16.42.1: FAIL"; fi
if "$FB" devices 2>/dev/null | tr -d '\r' | grep -qi fastboot; then
	echo "Phone still in fastboot (reboot cmd failed). Long-press power 10-15s, then: bash flash-fast.sh skipflash"
fi
exit 12
