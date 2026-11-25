#!/bin/bash
# Wait for fastboot, flash FAT32 userdata, reboot, monitor USB gadget appearance.
FB="/c/Users/wengchengjian/AppData/Local/Android/Sdk/platform-tools/fastboot.exe"
cd /f/project/pmos-munch || exit 1
echo "=== waiting for fastboot (up to 10 min) ==="
FOUND=0
for i in $(seq 1 300); do
  if "$FB" devices 2>/dev/null | tr -d '\r' | grep -qi "fastboot"; then
    FOUND=1
    echo "fastboot device appeared after $((i*2)) s"
    break
  fi
  sleep 2
done
if [ "$FOUND" != "1" ]; then
  echo "TIMEOUT: no fastboot device"
  exit 1
fi
"$FB" devices 2>&1 | tr -d '\r'
echo "=== flash userdata (1536MiB FAT32) ==="
time "$FB" flash userdata out/pmos-fat-userdata.img 2>&1 | tail -3
echo "=== set_active b (informational, may say no slots) ==="
"$FB" set_active b 2>&1 | head -1
echo "=== reboot ==="
"$FB" reboot 2>&1 | head -1
echo "=== monitor 240 s: USB gadget / net adapter ==="
for i in $(seq 1 120); do
  sleep 2
  T=$((i*2))
  FBDEV=$("$FB" devices 2>/dev/null | tr -d '\r' | grep -i fastboot | head -1)
  NET=$(powershell.exe -NoProfile -Command "Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { \$_.InterfaceDescription -match 'NCM|RNDIS|Remote NDIS|Gadget' } | Select-Object -First 1 -ExpandProperty InterfaceDescription" 2>/dev/null | tr -d '\r' | head -1)
  USB=$(powershell.exe -NoProfile -Command "Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { \$_.FriendlyName -match 'NCM|RNDIS|Linux|Gadget|Composite' } | Select-Object -First 2 -ExpandProperty FriendlyName" 2>/dev/null | tr -d '\r' | tr '\n' ';')
  echo "[$T s] fb=${FBDEV:+yes} net=${NET:-none} usb=${USB:-none}"
done
echo "=== monitor done ==="
