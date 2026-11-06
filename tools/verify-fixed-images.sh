#!/usr/bin/env bash
# 校验新打包的镜像（含新增的「init 架构/可执行性」检查）
set -uo pipefail
NAT=/mnt/c/Users/Public/natrium
V=$NAT/stage/tools/verify_bootimg.py
for f in boot-6.18.7-msmpmos-logger.img boot-6.12.10-msm-logger.img; do
  echo "================ $f ================"
  python3 "$V" "$NAT/$f" 2>&1 | grep -E '版本串|init:|initramfs 里的|全部检查|Traceback|AssertionError|⚠' || true
  echo
done
