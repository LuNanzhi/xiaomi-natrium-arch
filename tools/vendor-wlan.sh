#!/bin/sh
echo "=== /mnt/vendor/firmware/wlan/qca_cld ==="
ls -la /mnt/vendor/firmware/wlan/qca_cld 2>/dev/null | head -25
echo
echo "=== any .bin under vendor/firmware ==="
find /mnt/vendor/firmware -maxdepth 3 -type f 2>/dev/null | head -25
echo
echo "=== board-2.bin magic ==="
head -c 32 /lib/firmware/ath10k/QCA6174/hw3.0/board-2.bin | od -c | head -2
