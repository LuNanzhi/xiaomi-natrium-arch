#!/usr/bin/env bash
# 路线 B（postmarketOS）环境准备：从 git 获取 pmbootstrap 与 pmaports
# 注意：pmbootstrap 已从 PyPI 下架（全版本 yanked），只能从 git 安装
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "=== 0) 依赖 ==="
apt-get install -y --no-install-recommends git python3 >/dev/null 2>&1
echo "  git: $(git --version)"

echo
echo "=== 1) 克隆 pmbootstrap ==="
if [ ! -d /root/pmbootstrap ]; then
  git clone --depth 1 https://gitlab.postmarketos.org/postmarketOS/pmbootstrap.git /root/pmbootstrap 2>&1 | tail -2
fi
cd /root/pmbootstrap || exit 1
echo "  commit: $(git log --oneline -1)"
echo "  version: $(./pmbootstrap.py --version 2>&1 | head -1)"

echo
echo "=== 2) 顶层参数 ==="
./pmbootstrap.py --help 2>&1 | sed -n '1,45p'

echo
echo "=== 3) 是否拒绝以 root 运行 ==="
./pmbootstrap.py config 2>&1 | head -8

echo
echo "=== 4) 克隆 pmaports（含 device/archived/device-xiaomi-natrium）==="
if [ ! -d /root/pmaports/.git ]; then
  git clone --depth 1 https://gitlab.postmarketos.org/postmarketOS/pmaports.git /root/pmaports 2>&1 | tail -2
fi
echo "  设备包:"
ls -d /root/pmaports/device/archived/device-xiaomi-natrium 2>/dev/null || echo "  (未找到 archived 设备包)"
ls /root/pmaports/device/archived/device-xiaomi-natrium 2>/dev/null | head -8
echo "  内核包:"
ls -d /root/pmaports/device/testing/linux-postmarketos-qcom-msm8996 2>/dev/null || echo "  (未找到内核包)"

echo
echo "=== 5) 磁盘 ==="
df -h / | tail -1
