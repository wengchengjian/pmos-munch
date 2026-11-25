#!/bin/sh
set -e
SSID="CHANGE_ME_SSID"
PSK="CHANGE_ME_WIFI_PSK"
CONF=/etc/wpa_supplicant/wpa_supplicant-wlan0.conf
mkdir -p /etc/wpa_supplicant
cat > "$CONF" <<EOC
country=CN
ctrl_interface=DIR=/run/wpa_supplicant GROUP=netdev
update_config=1

network={
        ssid="$SSID"
        psk="$PSK"
        key_mgmt=WPA-PSK
}
EOC
chmod 600 "$CONF"
systemctl disable --now wpa_supplicant.service 2>/dev/null || true
systemctl enable wpa_supplicant@wlan0.service 2>&1 | tail -1
systemctl restart wpa_supplicant@wlan0.service
ip link set wlan0 up 2>/dev/null || true
sleep 6
echo "=== iw link ==="
iw dev wlan0 link 2>&1 | head -10
echo "=== dhcpcd ==="
dhcpcd -t 20 wlan0 2>&1 | tail -5 || true
sleep 2
echo "=== addr ==="
ip addr show wlan0 2>/dev/null | grep -E "inet |state" | head -4
echo "=== route ==="
ip route 2>/dev/null | head -5
echo "=== internet ==="
ping -c 2 -W 3 223.5.5.5 2>&1 | tail -3
