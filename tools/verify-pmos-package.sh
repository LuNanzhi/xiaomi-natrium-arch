#!/usr/bin/env bash
# 验收 pmOS 线刷包：内核版本、设备树里的 Sharp 面板、initramfs 里的模块、rootfs 内容
set -uo pipefail
PMOS=/mnt/c/Users/Public/natrium/pmos
TOOLS=/mnt/c/Users/Public/natrium/stage/tools
W=/tmp/verifypmos; rm -rf "$W"; mkdir -p "$W"

echo "=== 0) 包内容 ==="
ls -lh "$PMOS" 2>/dev/null || { echo "  还没有产物"; exit 1; }

BOOT=$(ls -S "$PMOS"/*.img 2>/dev/null | while read -r f; do
  # boot 镜像一般带 boot 字样或较小；取不是 rootfs 的那个
  case "$(basename "$f")" in *root*|natrium.img) ;; *) echo "$f"; break;; esac
done)
[ -n "$BOOT" ] || BOOT=$(ls "$PMOS"/boot*.img 2>/dev/null | head -1)
echo "  boot 镜像: $(basename "${BOOT:-无}")"

echo
echo "=== 1) boot.img 结构（头部参数 / cmdline）==="
if [ -n "$BOOT" ]; then
  python3 "$TOOLS/bootimg_info.py" "$BOOT" 2>&1 | head -20
fi

echo
echo "=== 2) 内核版本串 ==="
if [ -n "$BOOT" ]; then
  python3 "$TOOLS/verify_bootimg.py" "$BOOT" 2>&1 | grep -E '版本串|init:|全部检查|Assertion|架构' | head -8
fi

echo
echo "=== 3) 设备树里是否有 Sharp 面板 ==="
if [ -n "$BOOT" ]; then
  python3 - "$BOOT" <<'PY'
import struct, sys, zlib
d = open(sys.argv[1], "rb").read()
page = struct.unpack_from("<I", d, 8)[0] or 4096
ksize = struct.unpack_from("<I", d, 12)[0]
kernel = d[page:page+ksize]
for kw in (b"sharp,td4722-xcmd", b"jdi,fhd-r63452", b"xiaomi,natrium"):
    print("   %-22s %s" % (kw.decode(), "在" if kw in kernel else "不在"))
PY
fi

echo
echo "=== 4) initramfs 里是否带上了 Sharp 面板模块 ==="
if [ -n "$BOOT" ]; then
  python3 - "$BOOT" <<'PY'
import gzip, io, lzma, struct, sys, tarfile, zlib
d = open(sys.argv[1], "rb").read()
page = struct.unpack_from("<I", d, 8)[0] or 4096
ksize = struct.unpack_from("<I", d, 12)[0]
rsize = struct.unpack_from("<I", d, 16)[0]
rd = d[page+ksize:page+ksize+rsize]
kind = "?"
try:
    if rd[:6] == b"\xfd7zXZ\x00":
        raw = lzma.decompress(rd); kind = "xz"
    elif rd[:2] == b"\x1f\x8b":
        raw = gzip.decompress(rd); kind = "gzip"
    elif rd[:4] == b"0707" or rd[:6] == b"070701":
        raw = rd; kind = "cpio"
    else:
        raw = zlib.decompress(rd, 16+zlib.MAX_WBITS); kind = "zlib"
except Exception as e:
    print("   解压失败:", e); raw = b""
print("   initramfs 格式: %s, %d bytes" % (kind, len(raw)))
for kw in (b"panel-sharp-td4722-xcmd.ko", b"panel_sharp_td4722", b"panel-jdi-fhd-r63452.ko", b"init"):
    print("   含 %-32s %s" % (kw.decode(), "是" if kw in raw else "否"))
PY
fi

echo
echo "=== 5) rootfs 镜像 ==="
ROOT=$(ls "$PMOS"/*.img 2>/dev/null | grep -v "$(basename "${BOOT:-none}")" | head -1)
if [ -n "$ROOT" ]; then
  echo "  文件: $(basename "$ROOT")  $(stat -c%s "$ROOT") bytes"
  mkdir -p "$W/root"
  if mount -o loop,ro "$ROOT" "$W/root" 2>/dev/null; then
    echo "  --- 顶层目录 ---"; ls "$W/root" | head -12
    echo "  --- 是否 pmOS ---"; [ -f "$W/root/etc/os-release" ] && head -3 "$W/root/etc/os-release"
    echo "  --- Phosh 是否在内 ---"; ls "$W/root/usr/bin/phosh" 2>/dev/null || ls -d "$W/root/usr/lib/phosh" 2>/dev/null || echo "  (未直接看到 phosh 可执行文件)"
    echo "  --- 内核模块目录 ---"; ls "$W/root/lib/modules/" 2>/dev/null | head -3
    umount "$W/root"
  else
    echo "  (无法 loop 挂载，可能不是完整分区镜像；用 file 看类型)"
    file "$ROOT"
  fi
fi
