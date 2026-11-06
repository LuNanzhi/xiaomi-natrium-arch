#!/usr/bin/env bash
# Progress of the two pmOS-matched builds
set -uo pipefail
STAGE=/mnt/c/Users/Public/natrium/stage
for d in /root/build-6187 /root/build-6195; do
  echo "-- $d"
  if [ -d "$d" ]; then
    echo "   objects: $(find "$d" -name '*.o' 2>/dev/null | wc -l)"
    [ -f "$d/arch/arm64/boot/Image.gz" ] && echo "   Image.gz: $(stat -c%s "$d/arch/arm64/boot/Image.gz") bytes" || echo "   Image.gz: not yet"
  else
    echo "   (未开始)"
  fi
done
echo "-- 源码目录"
ls -d /root/linux-msm8996 /root/linux-6195 2>/dev/null || true
echo "-- 已产出的镜像"
ls "$STAGE"/boot-6.18.7-msmpmos-*.img "$STAGE"/boot-6.19.5-msmpmos-*.img 2>/dev/null | xargs -r -n1 basename || echo "   none yet"
echo "-- 运行中的 make"
ps -eo etime,cmd | grep -E 'make .*Image.gz' | grep -v grep | head -2
