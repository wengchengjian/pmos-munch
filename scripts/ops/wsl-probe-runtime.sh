#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.100
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
echo == paths ==
for t in redis-server redis-cli postgres initdb pg_ctl sysctl su; do printf \"%-14s \" \$t; command -v \$t || echo MISSING; done
echo == load modules ==
for m in overlay veth bridge br_netfilter ip_tables iptable_nat nf_nat xt_MASQUERADE xt_conntrack; do
  modprobe \$m 2>/tmp/m.err && echo OK \$m || { echo FAIL \$m; cat /tmp/m.err; }
done
echo == lsmod ==
lsmod | grep -E \"^(overlay|veth|bridge|br_netfilter|ip_tables|iptable_nat|nf_nat|xt_MASQUERADE|xt_conntrack)\" || true
echo == iptables ==
iptables -V 2>&1
iptables -L -n 2>&1 | head -8
echo == sysctl ==
sysctl net.ipv4.ip_forward net.bridge.bridge-nf-call-iptables 2>&1
echo == redis config ==
grep -nE \"^(bind|supervised|daemonize|logfile|dir|port|protected-mode)\" /etc/redis.conf | head -20
echo == redis dirs ==
ls -la /var/log/redis 2>/dev/null; ls -la /var/lib/redis | head
"' 2>&1 | grep -a -v "Permanently added"