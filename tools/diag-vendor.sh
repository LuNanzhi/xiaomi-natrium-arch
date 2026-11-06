#!/usr/bin/env bash
# 对比 ext4 超级块声明的文件系统大小与镜像实际大小（判断是否被截断）
set -uo pipefail
IMG="${1:-/root/ota-work/vendor.img}"
echo "镜像: $IMG  实际大小: $(stat -c%s "$IMG") bytes ($(( $(stat -c%s "$IMG") / 4096 )) 块)"

echo
echo "=== dumpe2fs -h（前 25 行）==="
dumpe2fs -h "$IMG" 2>&1 | head -25

echo
echo "=== 超级块原始字段（offset 1024 起）==="
python3 - "$IMG" <<'PY'
import struct
import sys

p = sys.argv[1]
with open(p, "rb") as f:
    f.seek(1024)
    sb = f.read(1024)
(ino, bcnt, rbcnt, fbcnt, fcnt, mnt, mt, mtc, lsize, lfrag, bsize, csize, ncg) = struct.unpack_from("<13I", sb, 0)
bs = 1024 << lsize
print("  s_inodes_count     :", ino)
print("  s_blocks_count     :", bcnt, "-> 文件系统大小 %.1f MB" % (bcnt * bs / 2**20))
print("  s_free_blocks_count:", fbcnt)
print("  s_log_block_size   :", lsize, "-> 块大小", bs)
print("  s_blocks_per_group :", struct.unpack_from("<I", sb, 32)[0])
print("  s_inodes_per_group :", struct.unpack_from("<I", sb, 40)[0])
print("  s_blocks_count_hi  :", struct.unpack_from("<I", sb, 0x150)[0] if len(sb) > 0x154 else "n/a")
PY
