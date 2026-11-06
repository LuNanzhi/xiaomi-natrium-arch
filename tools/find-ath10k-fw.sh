#!/bin/sh
mkdir -p /mnt/vendor /mnt/system
mount -o ro /dev/sde38 /mnt/vendor 2>&1 && echo "vendor mounted"
mount -o ro /dev/sde39 /mnt/system 2>&1 && echo "system mounted"

echo "=== vendor top ==="
ls /mnt/vendor 2>/dev/null | head -12
echo "=== system top ==="
ls /mnt/system 2>/dev/null | head -12

echo "=== ath10k / bdwlan files ==="
find /mnt/vendor /mnt/system -xdev \( -iname '*bdwlan*' -o -iname '*ath10k*' -o -iname 'board*.bin' -o -iname 'board-2.bin' \) 2>/dev/null | head -30

echo "=== firmware dirs ==="
ls /mnt/vendor/firmware 2>/dev/null | head -20
ls /mnt/system/etc/firmware 2>/dev/null | head -20
