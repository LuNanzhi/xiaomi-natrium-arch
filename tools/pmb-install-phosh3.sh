#!/usr/bin/env bash
# 先本地构建归档设备包，再装配 Phosh 系统
set -uo pipefail
PB=/root/pmbootstrap/pmbootstrap.py
WORK=/root/.local/var/pmbootstrap

echo "=== 1) 清理残留与锁 ==="
pkill -f 'apk.static' 2>/dev/null; pkill -f 'pmbootstrap.py' 2>/dev/null; sleep 2
find "$WORK" -name 'lock' -path '*apk*' -delete 2>/dev/null
rm -f "$WORK/log.txt"

echo
echo "=== 2) 构建设备包 device-xiaomi-natrium（归档设备必须本地构建）==="
date
timeout 1800 python3 "$PB" --as-root -y build device-xiaomi-natrium 2>&1 | tail -25
echo "build 退出码 $?"

echo
echo "=== 3) 本地包仓库 ==="
ls -lh "$WORK"/packages/*/aarch64/*.apk 2>/dev/null | tail -10

echo
echo "=== 4) 装配 Phosh 完整系统（最长 120 分钟）==="
date
timeout 7200 python3 "$PB" --as-root -y install --password 1234 --split 2>&1 | tail -45
echo "install 退出码 $?"
date
ls -lh "$WORK"/*.img 2>/dev/null
du -sh "$WORK" 2>/dev/null
