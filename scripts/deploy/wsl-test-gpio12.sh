#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.103
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"
$SSH "$H" 'cat > /tmp/gpio_hold' < /mnt/f/project/pmos-munch/tools/gpio_hold || exit 1
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "chmod +x /tmp/gpio_hold; chmod 755 /tmp/gpio_hold; nohup /tmp/gpio_hold 3 12 0 90 >/tmp/gpio.log 2>&1 & sleep 1; cat /tmp/gpio.log; grep gpio12 /sys/kernel/debug/gpio | tail -2"' 2>&1 | grep -v "Permanently added"
