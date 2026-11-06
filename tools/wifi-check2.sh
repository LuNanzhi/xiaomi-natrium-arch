#!/bin/sh
echo "=== uptime ==="
uptime
echo "=== regulatory ==="
iw reg get 2>/dev/null | head -4
echo "=== regdb loaded? ==="
dmesg 2>/dev/null | grep -iE "regulatory|cfg80211" | tail -5
echo "=== ath10k board ==="
dmesg 2>/dev/null | grep -iE "ath10k.*(board|firmware ver|country)" | tail -6
echo "=== wlan ==="
ip -brief addr show wlan0 2>&1
