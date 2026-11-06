#!/bin/sh
echo "=== links ==="
ip -brief link | head -10
echo "=== iwctl devices ==="
iwctl device list 2>&1 | head -10
echo "=== ath10k dmesg ==="
dmesg 2>/dev/null | grep -iE "ath10k|wlan|firmware" | tail -12
echo "=== regulatory.db present? ==="
ls -l /lib/firmware/regulatory.db* 2>&1
