#!/usr/bin/env bash
# 解包 pmOS initramfs（自动识别压缩格式）并查看根分区查找逻辑
set -uo pipefail
PMOS=/mnt/c/Users/Public/natrium/pmos
W=/tmp/irdump; rm -rf "$W"; mkdir -p "$W"

SRC="$PMOS/initramfs"
echo "=== 1) 识别格式并解包 ==="
head -c 6 "$SRC" | xxd | head -1
cd "$W"
case "$(head -c 6 "$SRC" | xxd -p)" in
  1f8b*)      echo "  gzip";   gzip -dc "$SRC" > ir.cpio;;
  fd377a585a00*) echo "  xz";  xz -dc "$SRC" > ir.cpio;;
  28b52ffd*)  echo "  zstd";  zstd -dc "$SRC" > ir.cpio;;
  *)          echo "  当作 cpio"; cp "$SRC" ir.cpio;;
esac
ls -l ir.cpio
file ir.cpio | head -1

cpio -idm --quiet < ir.cpio 2>/dev/null || cpio -idm < ir.cpio 2>&1 | tail -3
echo "  解出条目: $(find . -mindepth 1 | wc -l)"

echo
echo "=== 2) 顶层结构 ==="
ls -la | head -20

echo
echo "=== 3) init 脚本位置 ==="
find . -maxdepth 3 \( -name 'init' -o -name 'initramfs-init' -o -name 'pmos_continue_boot' \) 2>/dev/null | head

echo
echo "=== 4) 与“找根分区”相关的内容 ==="
INIT=$(find . -maxdepth 2 -name 'init' -type f | head -1)
echo "  init = $INIT"
[ -n "$INIT" ] && grep -n -iE 'root_uuid|blkid|find_root|wait_root|PARTLABEL|pmos_root|not found|rootfsopts' "$INIT" | head -40

echo
echo "=== 5) 查找函数全文 ==="
[ -n "$INIT" ] && awk 'BEGIN{p=0} /find_root|find_boot|wait_for_root|setup_root/{p=1} {if(p) print NR": "$0} p&&/^}/{p=0}' "$INIT" | head -70

echo
echo "=== 6) initramfs 里的块设备相关脚本 ==="
grep -rl 'blkid\|findfs' . 2>/dev/null | head -8
