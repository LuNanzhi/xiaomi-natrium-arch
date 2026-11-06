#!/usr/bin/env bash
# 解析手机 cache 分区镜像，找出 logger 镜像写下的诊断文件
set -uo pipefail
IMG=/mnt/c/Users/Public/natrium/cache.img
OUT=/mnt/c/Users/Public/natrium/diag-from-cache.txt

echo "=== ext4 几何 ==="
dumpe2fs -h "$IMG" 2>&1 | head -12

echo
echo "=== 根目录 ==="
debugfs -R 'ls -l /' "$IMG" 2>&1 | head -30

echo
echo "=== 找 natrium 相关文件 ==="
debugfs -R 'ls -l /' "$IMG" 2>&1 | grep -i natrium || echo "  根目录下没有 natrium 名字的文件"

FOUND=no
for p in /natrium-diag.txt /natrium/natrium-diag.txt /diag/natrium-diag.txt /lost+found/natrium-diag.txt; do
  if debugfs -R "stat $p" "$IMG" 2>/dev/null | grep -q 'Inode:'; then
    echo "  找到 $p"
    debugfs -R "cat $p" "$IMG" > "$OUT" 2>/dev/null || true
    if [ -s "$OUT" ]; then
      echo "  已写出 $OUT ($(stat -c%s "$OUT") bytes)"
      FOUND=yes
      break
    fi
  fi
done

if [ "$FOUND" = no ]; then
  echo
  echo "=== 文件不在预期位置，直接在原始镜像里搜文本 ==="
  strings -a "$IMG" > /tmp/raw.txt 2>/dev/null || true
  grep -n -m 10 -E 'natrium mainline|===== natrium|CACHE=|Linux version 6|Linux version 4' /tmp/raw.txt | head -20 || true
  # 如果找到日志起点，把从那里开始的一段文本切出来
  START=$(grep -n -m1 -E '===== natrium' /tmp/raw.txt | cut -d: -f1 || true)
  if [ -n "${START:-}" ]; then
    echo "  日志起点在第 $START 行，切出后续 4000 行"
    sed -n "${START},$((START+4000))p" /tmp/raw.txt > "$OUT"
    echo "  已写出 $OUT ($(stat -c%s "$OUT") bytes)"
  else
    echo "  原始镜像里也没有日志标记 —— 说明 logger 那一步没能写成文件"
    echo "  原始镜像里的 dmesg 片段抽样:"
    grep -m 15 -E 'Linux version|msm|drm|panel|wled|ufs' /tmp/raw.txt | head -15 || true
  fi
fi

echo
echo "=== 结果预览（前 40 行）==="
[ -s "$OUT" ] && head -40 "$OUT" || echo "(无输出文件)"
