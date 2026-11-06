#!/bin/sh
iwctl device wlan0 set-property Powered on 2>&1
sleep 1
iwctl station wlan0 scan 2>&1
sleep 5
iwctl station wlan0 get-networks 2>&1 | head -10
echo "=== connect ==="
PSK=$(grep '^PreSharedKey=' /var/lib/iwd/*.psk 2>/dev/null | head -1 | cut -d= -f2-)
iwctl station wlan0 connect ax6000 --passphrase "$PSK" 2>&1 | head -5
sleep 12
iwctl station wlan0 show 2>&1 | grep -E "State|Connected|Scanning" 
ip -brief addr show wlan0
echo "=== iwd recent ==="
journalctl -u iwd --since "-2 min" --no-pager 2>/dev/null | grep -iE "connect|handshake|reason|fail|assoc" | tail -8
