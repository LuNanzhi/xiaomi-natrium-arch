#!/bin/sh
. /etc/profile.d/natrium-proxy.sh
command -v iw >/dev/null 2>&1 || pacman -S --noconfirm iw wireless-regdb 2>&1 | tail -2

echo "=== before ==="
iw reg get 2>/dev/null | head -6
iw reg set CN 2>&1
sleep 2
echo "=== after ==="
iw reg get 2>/dev/null | head -6

echo "=== scan ==="
iwctl station wlan0 scan 2>&1
sleep 4
iwctl station wlan0 get-networks 2>&1 | head -12
