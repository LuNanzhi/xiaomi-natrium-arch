#!/usr/bin/env bash
# 重建 vendor.img 并打印诊断（避免 PowerShell↔bash 引号地狱）
set -uo pipefail
cd /root/ota-work
rm -f vendor.img
python3 /mnt/c/Users/Public/wsl/natrium-port-src/tools/sdat2img.py images/vendor.transfer.list vendor.new.dat vendor.img
echo
echo "=== ext4 几何 ==="
dumpe2fs -h vendor.img 2>&1 | grep -E 'Block count|Block size|Free blocks|Inode count'
echo
echo "=== 根目录 ==="
debugfs -R 'ls -l /' vendor.img 2>&1 | head -22
echo
echo "=== /lib/hw ==="
debugfs -R 'ls -l /lib/hw' vendor.img 2>&1 | head -20
echo
echo "=== /lib/modules ==="
debugfs -R 'ls -l /lib/modules' vendor.img 2>&1 | head -20
