#!/usr/bin/env bash
# 路线 B：构建 postmarketOS 的 natrium 内核包（长任务）
set -uo pipefail
PB=/root/pmbootstrap/pmbootstrap.py
WORK=/root/.local/var/pmbootstrap

echo "=== 0) 清理被刷屏撑大的日志 ==="
ls -l "$WORK/log.txt" 2>/dev/null
rm -f "$WORK/log.txt" /root/.local/var/pmbootstrap/log.txt.* 2>/dev/null
echo "  已清理"

echo
echo "=== 1) 设备包与内核包的关系 ==="
grep -E '^(pkgname|pkgver|depends|_flavor|source)=' /root/pmaports/device/archived/device-xiaomi-natrium/APKBUILD 2>/dev/null | head -12
echo "--- 内核包版本 ---"
grep -E '^(pkgname|pkgver|pkgrel|_flavor|_tag)=' /root/pmaports/device/testing/linux-postmarketos-qcom-msm8996/APKBUILD 2>/dev/null | head -8

echo
echo "=== 2) 构建内核包（会先下载 Alpine chroot，最长 90 分钟）==="
date
timeout 5400 python3 "$PB" --as-root -y build linux-postmarketos-qcom-msm8996 2>&1 | tail -40
echo "构建结束，退出码 $?"
date

echo
echo "=== 3) 结果 ==="
ls -lh "$WORK"/packages/*/*/*.apk 2>/dev/null | tail -10
df -h / | tail -1
ls -l "$WORK/log.txt" 2>/dev/null
