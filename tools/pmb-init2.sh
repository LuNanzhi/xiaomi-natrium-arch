#!/usr/bin/env bash
# 用「回车接受默认值」的方式完成 pmbootstrap init
set -uo pipefail
PB=/root/pmbootstrap/pmbootstrap.py

echo "=== 用换行喂入交互提示 ==="
yes '' | timeout 300 python3 "$PB" --as-root -y init 2>&1 | tail -30

echo
echo "=== 工作目录 ==="
ls -la /root/.local/var/pmbootstrap 2>/dev/null | head -12

echo
echo "=== status ==="
timeout 120 python3 "$PB" --as-root status 2>&1 | sed -n '1,35p'
