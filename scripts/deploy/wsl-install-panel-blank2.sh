#!/bin/bash
set -u
export SSHPASS=CHANGE_ME_PASSWORD
H=user@192.168.0.103
SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"
$SSH "$H" 'cat > /tmp/gpio_hold' < /mnt/f/project/pmos-munch/tools/gpio_hold || exit 1
$SSH "$H" 'cat > /tmp/panel-blank.service' < /mnt/f/project/pmos-munch/units/panel-blank.service || exit 1
$SSH "$H" 'echo CHANGE_ME_PASSWORD | sudo -S -p "" sh -c "
install -m 755 /tmp/gpio_hold /usr/local/bin/gpio_hold
install -m 644 /tmp/panel-blank.service /etc/systemd/system/panel-blank.service
systemctl daemon-reload
systemctl enable --now panel-blank.service
sleep 2
systemctl is-active panel-blank.service
ls -la /usr/local/bin/gpio_hold /etc/systemd/system/panel-blank.service
"' 2>&1 | grep -v "Permanently added" | tail -10
