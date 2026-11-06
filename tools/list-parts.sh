#!/bin/sh
echo "=== block devices ==="
lsblk -o NAME,SIZE,FSTYPE,LABEL 2>/dev/null | tail -25
echo
echo "=== partitions with sizes (from kernel) ==="
cat /proc/partitions | awk 'NR>2 && $3>200000 {printf "/dev/%s %d MB\n", $4, $3/1024}'
