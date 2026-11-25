#!/bin/sh
rfkill list 2>/dev/null | head -6
ip link set wlan0 up 2>/dev/null
sleep 2
iw dev wlan0 scan 2>/dev/null | awk '/^BSS/{bss=$2} /signal:/{sig=$0} /SSID:/{print sig " | " $0}'
