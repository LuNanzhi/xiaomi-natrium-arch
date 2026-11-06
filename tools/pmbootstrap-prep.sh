#!/usr/bin/env bash
# 准备 pmbootstrap（路线 B：postmarketOS）—— 先探明它能否非交互式驱动
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "=== 0) 磁盘空间 ==="
df -h / | tail -1

echo "=== 1) 装 python venv 并安装 pmbootstrap ==="
apt-get install -y --no-install-recommends python3-venv python3-pip >/dev/null 2>&1
if [ ! -x /root/pmb-venv/bin/pmbootstrap ]; then
  python3 -m venv /root/pmb-venv >/dev/null 2>&1 || { echo "!! venv 建立失败"; exit 1; }
  /root/pmb-venv/bin/pip install --quiet --upgrade pip >/dev/null 2>&1
  /root/pmb-venv/bin/pip install --quiet pmbootstrap 2>&1 | tail -3
fi
echo "  pmbootstrap: $(/root/pmb-venv/bin/pmbootstrap --version 2>&1 | head -1)"

echo
echo "=== 2) 顶层参数 ==="
/root/pmb-venv/bin/pmbootstrap --help 2>&1 | sed -n '1,40p'

echo
echo "=== 3) init 的参数 ==="
/root/pmb-venv/bin/pmbootstrap init --help 2>&1 | sed -n '1,40p'

echo
echo "=== 4) config 的参数 ==="
/root/pmb-venv/bin/pmbootstrap config --help 2>&1 | sed -n '1,30p'

echo
echo "=== 5) 已有配置? ==="
ls -l /root/.config/pmbootstrap* 2>/dev/null || echo "  (无)"
