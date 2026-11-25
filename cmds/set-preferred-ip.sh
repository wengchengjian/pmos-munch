#!/bin/sh
sed -i 's#-i wlan0 -s#-i wlan0 -r 192.168.0.100 -s#' /etc/systemd/system/wlan0-dhcp.service
grep ExecStart /etc/systemd/system/wlan0-dhcp.service
systemctl daemon-reload
systemctl restart wlan0-dhcp.service
sleep 8
ip addr show wlan0 | grep inet
