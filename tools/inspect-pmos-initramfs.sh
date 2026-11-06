#!/usr/bin/env bash
# 从我们生成的 initramfs 里读出 pmOS 的 init 脚本，弄清它是如何定位根分区的
set -uo pipefail
PMOS=/mnt/c/Users/Public/natrium/pmos
W=/tmp/irdump; rm -rf "$W"; mkdir -p "$W"

echo "=== 1) 解包 initramfs ==="
cd "$W"
xz -dc "$PMOS/initramfs" > initramfs.cpio 2>/dev/null || cp "$PMOS/initramfs" initramfs.cpio
file initramfs.cpio | head -2
cpio -id --quiet < initramfs.cpio 2>/dev/null || true
ls | head -20

echo
echo "=== 2) 顶层脚本 ==="
for f in init initramfs-init sbin/init usr/bin/pmos_continue_boot; do
  [ -e "$f" ] && { echo "--- $f ($(stat -c%s "$f") bytes) ---"; }
done

echo
echo "=== 3) init 里与“找根分区”相关的逻辑 ==="
if [ -f init ]; then
  grep -n -iE 'root_uuid|pmos_root|blkid|find_root|wait.*root|PARTLABEL|LABEL|rootfsopts|not found' init | head -40
fi

echo
echo "=== 4) 完整的查找函数（若存在）==="
if [ -f init ]; then
  awk '/find_root|find_root_partition|wait_root|setup_root/{p=1} p{print NR": "$0} p&&/^}/{p=0}' init | head -60
fi

echo
echo "=== 5) 系统里的初始化脚本（init.d / 相关）==="
find "$W" -maxdepth 3 -name '*init*' -type f 2>/dev/null | head -10
