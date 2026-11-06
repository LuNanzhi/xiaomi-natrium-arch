#!/usr/bin/env bash
# 找到 pmbootstrap 导出的镜像并复制到 Windows 交付目录
set -uo pipefail
WORK=/root/.local/var/pmbootstrap
NAT=/mnt/c/Users/Public/natrium
DEST="$NAT/pmos"

echo "=== 1) /tmp/postmarketos-export 内容（含符号链接目标）==="
ls -la /tmp/postmarketos-export/ 2>/dev/null || echo "  目录不存在"

echo
echo "=== 2) 在工作目录里搜索镜像文件 ==="
find "$WORK" -maxdepth 4 -name '*.img' -size +1M 2>/dev/null | head -10

echo
echo "=== 3) 复制到 $DEST ==="
mkdir -p "$DEST"
copy() {
  local src="$1" name="$2"
  if [ -f "$src" ]; then
    cp -fL "$src" "$DEST/$name"
    printf '  %-28s <- %s  (%s)\n' "$name" "$src" "$(du -h "$src" | cut -f1)"
  fi
}

# 优先用 /tmp/postmarketos-export 里的软链
if [ -d /tmp/postmarketos-export ]; then
  for f in /tmp/postmarketos-export/*; do
    [ -e "$f" ] || continue
    base=$(basename "$f")
    case "$base" in
      boot.img)               copy "$f" "boot.img";;
      *-boot.img)             copy "$f" "boot-partition.img";;
      *-root.img)             cp -fL "$f" "$DEST/root.img" && echo "  root.img <- $f  ($(du -hL "$f" | cut -f1))";;
      initramfs|vmlinuz)      copy "$f" "$base";;
    esac
  done
fi

# 兜底：直接在 work 目录里找
[ -f "$DEST/boot.img" ] || copy "$WORK/xiaomi-natrium-boot.img" "boot.img"
[ -f "$DEST/root.img" ] || copy "$WORK/xiaomi-natrium-root.img" "root.img"

echo
echo "=== 4) 交付目录内容 ==="
ls -lh "$DEST" 2>/dev/null

echo
echo "=== 5) 校验 boot.img ==="
if [ -f "$DEST/boot.img" ]; then
  python3 "$NAT/stage/tools/bootimg_info.py" "$DEST/boot.img" 2>&1 | head -14
  echo "  --- 设备树里的面板 ---"
  python3 - "$DEST/boot.img" <<'PY'
import struct, sys
d = open(sys.argv[1], "rb").read()
page = struct.unpack_from("<I", d, 8)[0] or 2048
ksize = struct.unpack_from("<I", d, 12)[0]
kernel = d[page:page+ksize]
for kw in (b"sharp,td4722-xcmd", b"jdi,fhd-r63452", b"xiaomi,natrium"):
    print("   %-22s %s" % (kw.decode(), "在" if kw in kernel else "不在"))
i = kernel.find(b"Linux version")
print("   内核版本串:", kernel[i:i+90].split(b"\x00")[0].decode("utf-8","replace") if i>=0 else "未找到")
PY
fi

echo
echo "=== 6) 磁盘 ==="
du -sh "$WORK" 2>/dev/null
df -h / | tail -1
