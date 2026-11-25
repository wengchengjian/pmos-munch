#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.103
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"
echo "== gpiochip3 info =="
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "cat /sys/bus/gpio/devices/gpiochip3/label /sys/bus/gpio/devices/gpiochip3/ngpio 2>/dev/null; grep -A4 \"gpiochip3\" /sys/kernel/debug/gpio 2>/dev/null | head -8; grep -E \"gpio12|gpio50\" /sys/kernel/debug/gpio 2>/dev/null | head -6"' 2>&1 | grep -v "Permanently added"
echo "== install cross gcc =="
export http_proxy=http://127.0.0.1:7897 https_proxy=http://127.0.0.1:7897
which aarch64-linux-gnu-gcc || { sudo -E apt-get update -qq >/tmp/apt.log 2>&1 && sudo -E apt-get install -y -qq gcc-aarch64-linux-gnu >>/tmp/apt.log 2>&1 && echo installed || { echo APT_FAILED; tail -5 /tmp/apt.log; }; }
aarch64-linux-gnu-gcc --version 2>/dev/null | head -1
