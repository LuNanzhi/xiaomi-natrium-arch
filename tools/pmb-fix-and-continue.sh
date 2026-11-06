#!/usr/bin/env bash
# 修复 apk-tools-static 找不到的问题（清掉换镜像前的旧索引缓存），然后继续流水线
set -uo pipefail
PB=/root/pmbootstrap/pmbootstrap.py
WORK=/root/.local/var/pmbootstrap

echo "=== 1) 确认镜像里确实有 apk-tools-static ==="
for u in "https://mirrors.tuna.tsinghua.edu.cn/alpine/edge/main/x86_64/" \
         "https://mirrors.tuna.tsinghua.edu.cn/alpine/edge/main/aarch64/"; do
  n=$(curl -s --max-time 25 -L "$u" 2>/dev/null | grep -c 'apk-tools-static')
  echo "  $u -> 命中 $n 个 apk-tools-static"
done
echo "  --- 顺带看 latest-stable（有时 edge 索引不同步）---"
curl -s --max-time 25 -L "https://mirrors.tuna.tsinghua.edu.cn/alpine/edge/main/x86_64/" 2>/dev/null | grep -oE 'apk-tools-static[-0-9a-z._]*\.apk' | head -3

echo
echo "=== 2) 清掉缓存的索引与 apk 缓存（换镜像前抓的）==="
ls -d "$WORK"/cache_apk_* "$WORK"/cache_http 2>/dev/null
rm -rf "$WORK"/cache_apk_x86_64 "$WORK"/cache_apk_aarch64 "$WORK"/cache_apk_* 2>/dev/null
rm -rf "$WORK"/cache_http 2>/dev/null
pkill -f 'apk.static' 2>/dev/null; sleep 2
echo "  已清理"

echo
echo "=== 3) 刷新包索引 ==="
timeout 900 python3 "$PB" --as-root -y update 2>&1 | tail -15

echo
echo "=== 4) 重新构建内核包（用 Sharp 补丁树，最长 90 分钟）==="
date
timeout 7200 python3 "$PB" --as-root -y build --src=/root/linux-sharp linux-postmarketos-qcom-msm8996 2>&1 | tail -30
echo "内核包退出码 $?"
ls -lh "$WORK"/packages/*/aarch64/linux-postmarketos-qcom-msm8996*.apk 2>/dev/null

echo
echo "=== 5) 构建设备包 ==="
timeout 3600 python3 "$PB" --as-root -y build device-xiaomi-natrium 2>&1 | tail -15
echo "设备包退出码 $?"

echo
echo "=== 6) 装配 Phosh 系统（最长 150 分钟）==="
date
timeout 9000 python3 "$PB" --as-root -y install --password 1234 --split 2>&1 | tail -35
echo "install 退出码 $?"
date
ls -lh "$WORK"/*.img 2>/dev/null
du -sh "$WORK" 2>/dev/null
