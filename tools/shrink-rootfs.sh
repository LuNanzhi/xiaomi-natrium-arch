#!/usr/bin/env bash
# 给 root.img 瘦身：收缩文件系统到最小，再截断镜像（UUID 不变，pmOS 首启会自动扩容）
set -uo pipefail
IMG=/mnt/c/Users/Public/natrium/pmos/root.img
OUT=/mnt/c/Users/Public/natrium/pmos/root-small.img

echo "=== 0) 原始大小 ==="
ls -lh "$IMG" | awk '{print "  "$5"  "$9}'

echo
echo "=== 1) 从已修好的 root.img 复制一份来做瘦身 ==="
rm -f "$OUT"
cp "$IMG" "$OUT"
ls -lh "$OUT" | awk '{print "  "$5}'

echo
echo "=== 2) 强制 fsck（resize 前必须干净）==="
e2fsck -f -y "$OUT" 2>&1 | tail -5

echo
echo "=== 3) 收缩文件系统到最小 ==="
resize2fs -M "$OUT" 2>&1 | tail -5

echo
echo "=== 4) 读回新尺寸并截断镜像 ==="
BLOCKS=$(dumpe2fs -h "$OUT" 2>/dev/null | awk -F: '/Block count/{gsub(/ /,"",$2); print $2}')
BSIZE=$(dumpe2fs -h "$OUT" 2>/dev/null | awk -F: '/Block size/{gsub(/ /,"",$2); print $2}')
echo "  blocks=$BLOCKS block_size=$BSIZE"
SIZE=$((BLOCKS * BSIZE))
echo "  新镜像大小 = $((SIZE/1024/1024)) MB"
truncate -s "$SIZE" "$OUT"

echo
echo "=== 5) 复核（UUID 必须不变）==="
blkid "$OUT"
blkid "$IMG"
echo "  --- 文件系统完整性 ---"
e2fsck -f -n "$OUT" 2>&1 | tail -3

echo
echo "=== 6) fstab 里 /boot 是否仍是注释状态 ==="
W=/mnt/smallcheck; mkdir -p "$W"
if mount -o loop,ro "$OUT" "$W" 2>/dev/null; then
  cat "$W/etc/fstab"
  umount "$W"
fi

echo
echo "=== 7) 结果 ==="
ls -lh /mnt/c/Users/Public/natrium/pmos/*.img | awk '{print "  "$5"  "$9}'
