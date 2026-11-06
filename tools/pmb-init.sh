#!/usr/bin/env bash
# 初始化 pmbootstrap 工作目录（work folder version 需要 init 来建立）
set -uo pipefail
PB=/root/pmbootstrap/pmbootstrap.py

echo "=== 0) 看看 pmbootstrap 认为工作目录该有什么 ==="
grep -rn "work folder version" /root/pmbootstrap/pmb/ 2>/dev/null | head -3
grep -rn "workdir_version\|WORKDIR_VERSION\|\.version" /root/pmbootstrap/pmb/config/__init__.py 2>/dev/null | head -10

echo
echo "=== 1) 运行 init（非交互，最多 240 秒）==="
timeout 240 python3 "$PB" --as-root -y init < /dev/null 2>&1 | tail -35

echo
echo "=== 2) 工作目录内容 ==="
ls -la /root/.local/var/pmbootstrap 2>/dev/null | head -12

echo
echo "=== 3) status ==="
python3 "$PB" --as-root status 2>&1 | sed -n '1,30p'
