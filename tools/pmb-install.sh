#!/usr/bin/env bash
# 路线 B：组装 postmarketOS 镜像（使用 pmOS 官方预编译内核包），并导出产物
set -uo pipefail
PB=/root/pmbootstrap/pmbootstrap.py
WORK=/root/.local/var/pmbootstrap

echo "=== 0) pmOS 预编译内核包 ==="
find "$WORK" -name 'linux-postmarketos-qcom-msm8996*.apk' 2>/dev/null | head -5
find "$WORK" -name 'device-xiaomi-natrium*.apk' 2>/dev/null | head -3

echo
echo "=== 1) install（最长 90 分钟；会下载 rootfs 包并生成 boot.img + root 镜像）==="
date
timeout 5400 python3 "$PB" --as-root -y install --password 1234 --split 2>&1 | tail -60
RC=$?
echo "install 退出码 $RC"
date

echo
echo "=== 2) 产物 ==="
ls -lh /root/.local/var/pmbootstrap/*.img 2>/dev/null
find "$WORK" -name '*.img' -newermt '-3 hours' 2>/dev/null | head -10
du -sh "$WORK" 2>/dev/null

echo
echo "=== 3) export（把产物软链到 /tmp/postmarketos-export）==="
timeout 900 python3 "$PB" --as-root export 2>&1 | tail -20
ls -lL /tmp/postmarketos-export/ 2>/dev/null | head -20

echo
echo "=== 4) 拷贝到 Windows 可访问目录 ==="
mkdir -p /mnt/c/Users/Public/natrium/pmos
for f in /tmp/postmarketos-export/*; do
  [ -e "$f" ] || continue
  cp -fL "$f" /mnt/c/Users/Public/natrium/pmos/ 2>/dev/null && echo "  copied $(basename "$f")"
done
ls -lh /mnt/c/Users/Public/natrium/pmos/ 2>/dev/null
df -h / | tail -1
