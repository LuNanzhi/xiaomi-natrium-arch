#!/usr/bin/env bash
# 全盘找 pmbootstrap 生成的镜像，并复制到交付目录
set -uo pipefail
WORK=/root/.local/var/pmbootstrap
NAT=/mnt/c/Users/Public/natrium
DEST="$NAT/pmos"

echo "=== 1) 搜索所有大于 1MB 的 img ==="
find / -xdev \( -path /proc -o -path /sys -o -path /mnt/c \) -prune -o -type f -name '*.img' -size +1M -print 2>/dev/null | head -20

echo
echo "=== 2) 搜索 export 目录 ==="
find / -xdev -type d -name 'postmarketos-export' 2>/dev/null | head -5
ls -la "$WORK/export" 2>/dev/null | head -10
ls -la /root/.local/var/pmbootstrap/ 2>/dev/null | head -20

echo
echo "=== 3) 复制 ==="
mkdir -p "$DEST"
BOOTIMG="$WORK/chroot_rootfs_xiaomi-natrium/boot/boot.img"
[ -f "$BOOTIMG" ] && cp -f "$BOOTIMG" "$DEST/boot.img" && echo "  boot.img <- $BOOTIMG ($(du -h "$BOOTIMG" | cut -f1))"

# 分区镜像（split 安装产物）
for cand in $(find / -xdev \( -path /proc -o -path /sys -o -path /mnt/c \) -prune -o -type f \
             \( -name 'xiaomi-natrium-root.img' -o -name '*root.img' -o -name 'xiaomi-natrium-boot.img' \) -print 2>/dev/null | head -6); do
  base=$(basename "$cand")
  case "$base" in
    *root.img) cp -f "$cand" "$DEST/root.img" && echo "  root.img <- $cand ($(du -h "$cand" | cut -f1))";;
    *boot.img) [ -f "$DEST/boot.img" ] || cp -f "$cand" "$DEST/boot.img" && echo "  boot.img <- $cand";;
  esac
done

# initramfs 与内核（备用）
[ -f "$WORK/chroot_rootfs_xiaomi-natrium/boot/initramfs" ] && cp -f "$WORK/chroot_rootfs_xiaomi-natrium/boot/initramfs" "$DEST/initramfs" && echo "  initramfs 已复制"
[ -f "$WORK/chroot_rootfs_xiaomi-natrium/boot/vmlinuz" ] && cp -f "$WORK/chroot_rootfs_xiaomi-natrium/boot/vmlinuz" "$DEST/vmlinuz" && echo "  vmlinuz 已复制"

echo
echo "=== 4) 交付目录 ==="
ls -lh "$DEST" 2>/dev/null

echo
echo "=== 5) boot.img 结构校验 ==="
if [ -f "$DEST/boot.img" ]; then
  python3 "$NAT/stage/tools/bootimg_info.py" "$DEST/boot.img" 2>&1 | head -16
  echo
  python3 - "$DEST/boot.img" <<'PY'
import lzma, gzip, struct, sys
d = open(sys.argv[1], "rb").read()
magic = d[:8]
page = struct.unpack_from("<I", d, 8)[0] or 2048
ksize = struct.unpack_from("<I", d, 12)[0]
rsize = struct.unpack_from("<I", d, 16)[0]
kernel = d[page:page+ksize]
print("  头部 magic:", magic)
print("  page=%d kernel=%d ramdisk=%d" % (page, ksize, rsize))
i = kernel.find(b"Linux version")
print("  内核版本串:", kernel[i:i+90].split(b"\x00")[0].decode("utf-8","replace") if i>=0 else "未找到")
for kw in (b"sharp,td4722-xcmd", b"jdi,fhd-r63452", b"xiaomi,natrium"):
    print("   %-20s %s" % (kw.decode(), "在" if kw in kernel else "不在"))
rd = d[page+ksize:page+ksize+rsize]
raw = b""
try:
    if rd[:6] == b"\xfd7zXZ\x00": raw = lzma.decompress(rd)
    elif rd[:2] == b"\x1f\x8b":   raw = gzip.decompress(rd)
    elif rd[:6] in (b"070701", b"070702"): raw = rd
except Exception as e:
    print("  ramdisk 解压失败:", e)
print("  ramdisk 解压后 %d bytes" % len(raw))
for kw in (b"panel-sharp-td4722-xcmd.ko", b"panel_sharp_td4722", b"init"):
    print("   含 %-28s %s" % (kw.decode(), "是" if kw in raw else "否"))
PY
fi
