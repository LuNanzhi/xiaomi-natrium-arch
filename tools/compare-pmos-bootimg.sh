#!/usr/bin/env bash
# 对比 pmOS 官方 boot.img 与我们自己打包的 boot.img（参数/cmdline/DTB）
set -uo pipefail
NAT=/mnt/c/Users/Public/natrium
PMOS=$NAT/pmos
TOOLS=$NAT/stage/tools

echo "=== pmOS 产物内容 ==="
ls -lh "$PMOS" 2>/dev/null || { echo "  (还没导出)"; exit 1; }

echo
echo "=== pmOS boot.img 参数 ==="
for f in "$PMOS"/*boot*.img "$PMOS"/boot.img; do
  [ -f "$f" ] || continue
  echo "--- $(basename "$f") ---"
  python3 "$TOOLS/bootimg_info.py" "$f" 2>&1 | head -25
  echo
  echo "--- 独立校验（含内核版本串 / DTB 选取字段 / init 架构）---"
  python3 "$TOOLS/verify_bootimg.py" "$f" 2>&1 | head -30
  echo
  break
done

echo
echo "=== 我们的 boot.img（对照） ==="
python3 "$TOOLS/bootimg_info.py" "$NAT/boot-6187-bbshell.img" 2>&1 | head -25
