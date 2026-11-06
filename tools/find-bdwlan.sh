#!/bin/sh
echo "=== /mnt/vendor/firmware/wlan ==="
ls -la /mnt/vendor/firmware/wlan 2>/dev/null | head -20
echo
echo "=== find bdwlan anywhere in vendor ==="
find /mnt/vendor -xdev -iname '*bdwlan*' 2>/dev/null | head -20
echo
echo "=== vendor/firmware_mnt ==="
ls /mnt/vendor/firmware_mnt 2>/dev/null | head -10
echo
echo "=== already present in our rootfs? ==="
ls -l /lib/firmware/ath10k/QCA6174/hw3.0/ 2>/dev/null | head
echo
echo "=== system firmware ath10k dir ==="
ls -l /mnt/system/usr/lib/firmware/ath10k/QCA6174/hw3.0/ 2>/dev/null | head -10
