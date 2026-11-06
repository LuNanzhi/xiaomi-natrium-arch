#!/usr/bin/env bash
# 修掉 root.img 里指向不存在分区的 /boot 行（黑屏元凶），并复核
set -uo pipefail
IMG=/mnt/c/Users/Public/natrium/pmos/root.img
W=/mnt/fixroot

echo "=== 1) 备份原镜像（便于回退）==="
if [ ! -f "$IMG.orig" ]; then
  cp "$IMG" "$IMG.orig"
  echo "  已备份为 $(basename "$IMG").orig ($(du -h "$IMG.orig" | cut -f1))"
else
  echo "  备份已存在"
fi

echo
echo "=== 2) 挂载并修改 fstab ==="
mkdir -p "$W"
mount -o loop,rw "$IMG" "$W" || { echo "!! 挂载失败"; exit 1; }
echo "  --- 修改前 ---"
cat "$W/etc/fstab"
cp "$W/etc/fstab" "$W/etc/fstab.bak"
# 把 /boot 行注释掉（匹配包含 /boot 的那一行）
sed -i -E 's|^(UUID=[0-9a-f-]+[[:space:]]+/boot[[:space:]].*)$|# \1   # disabled: no separate boot partition on this device (initramfs lives in Android boot.img)|' "$W/etc/fstab"
echo "  --- 修改后 ---"
cat "$W/etc/fstab"
sync
umount "$W"
echo "  已卸载并写回"

echo
echo "=== 3) 复核（重新挂载只读）==="
mount -o loop,ro "$IMG" "$W"
cat "$W/etc/fstab"
ls -l "$W/etc/fstab.bak" 2>/dev/null
umount "$W"

echo
echo "=== 4) 镜像现在是 ==="
blkid "$IMG"
ls -lh "$IMG" "$IMG.orig"
