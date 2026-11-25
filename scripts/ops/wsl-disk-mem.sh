#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.103
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
echo \"== block devices (sysfs) ==\"
for b in /sys/class/block/*; do
  n=\$(basename \$b)
  sz=\$(cat \$b/size 2>/dev/null)
  [ -n \"\$sz\" ] || continue
  case \$n in loop*) continue;; esac
  echo \"\$n \$((sz*512/1024/1024)) MiB\"
done
echo \"== partitions ==\"
cat /proc/partitions
echo \"== mounts ==\"
mount | grep -E \" / | /boot \"
echo \"== df ==\"
df -h / /boot
echo \"== rootfs file ==\"
ls -lh /boot/rootfs.img 2>/dev/null
echo \"== memory ==\"
grep -E \"MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree\" /proc/meminfo
echo \"== cpu ==\"
nproc
grep -m1 -E \"model name|Hardware\" /proc/cpuinfo
"' 2>&1 | grep -a -v "Permanently added"
