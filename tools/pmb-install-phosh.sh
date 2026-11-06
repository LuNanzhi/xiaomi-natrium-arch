#!/usr/bin/env bash
# 路线 B：切换到 Phosh 触摸界面并组装完整系统（长任务）
set -uo pipefail
PB=/root/pmbootstrap/pmbootstrap.py
WORK=/root/.local/var/pmbootstrap

echo "=== 1) 切换 UI 到 phosh（触摸界面，设备包自带 phoc.ini）==="
python3 "$PB" --as-root config ui phosh 2>&1 | tail -3
python3 "$PB" --as-root config ui 2>&1 | tail -2

echo
echo "=== 2) 清理被刷屏撑大的日志并开始 install ==="
rm -f "$WORK/log.txt"
date
timeout 7200 python3 "$PB" --as-root -y install --password 1234 --split --add postmarketos-ui-phosh 2>&1 | tail -60
echo "install 退出码 $?"
date

echo
echo "=== 3) 产物 ==="
find "$WORK" -maxdepth 2 -name '*.img' 2>/dev/null | head
ls -lh "$WORK"/*.img 2>/dev/null
du -sh "$WORK" 2>/dev/null
df -h / | tail -1
