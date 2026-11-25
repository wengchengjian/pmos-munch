#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.100
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
echo == iptables/kmod packages ==
for p in iptables iptables-nft nftables kmod; do printf \"%-14s \" \$p; apk search -x \$p 2>/dev/null | head -1; done
echo == tools ==
for t in modprobe iptables nft; do printf \"%-10s \" \$t; command -v \$t || echo MISSING; done
echo == kernel ==
uname -r
echo == modules ==
K=/usr/lib/modules/\$(uname -r)/kernel
for m in fs/overlayfs/overlay.ko drivers/net/veth.ko net/bridge/br_netfilter.ko net/ipv4/netfilter/iptable_nat.ko net/netfilter/xt_MASQUERADE.ko net/netfilter/xt_conntrack.ko; do
  ls \$K/\$m* 2>/dev/null || echo MISSING \$m
done
echo == docker simulate ==
apk add --simulate docker docker-cli kmod iptables 2>&1 | tail -25
"' 2>&1 | grep -a -v "Permanently added"