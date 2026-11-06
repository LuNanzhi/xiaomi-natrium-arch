#!/usr/bin/env bash
set -uo pipefail
NAT=/mnt/c/Users/Public/natrium
V=$NAT/stage/tools/verify_bootimg.py
for f in boot-6.12.10-msm-logger.img boot-6.17.8-msm-logger.img; do
  echo "================ $f ================"
  python3 "$V" "$NAT/$f" 2>&1 | grep -E '版本串|model|msm-id|board-id|全部检查' || true
  echo
done
