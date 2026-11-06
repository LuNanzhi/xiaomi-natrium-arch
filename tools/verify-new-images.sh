#!/usr/bin/env bash
# 校验交付目录里的两版新内核
set -uo pipefail
NAT=/mnt/c/Users/Public/natrium
V=/mnt/c/Users/Public/natrium/stage/tools/verify_bootimg.py
for f in boot-6.18.7-msmpmos-logger.img boot-6.19.5-msmpmos-logger.img; do
  echo "================ $f ================"
  python3 "$V" "$NAT/$f" 2>&1 | grep -E '版本串|model|msm-id|board-id|注:|条目|全部检查' || true
  echo
done
