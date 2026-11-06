#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 从 vendor.img 抽出厂商 HAL / 内核模块，并统计它们对下游内核私有接口的引用。
# 先试 loop 挂载（最省事），失败则用 debugfs 逐文件 dump。
# 用法: dump-vendor-files.sh <vendor.img> <输出目录>
# ---------------------------------------------------------------------------
set -uo pipefail
IMG="${1:?用法: dump-vendor-files.sh <vendor.img> <outdir>}"
OUT="${2:-/mnt/c/Users/Public/wsl/ota-analysis}"
D=/root/vendor-tree
MK=/mnt/vimg
rm -rf "$D"; mkdir -p "$D" "$OUT" "$MK"

DIRS="lib/hw lib64/hw lib/modules bin/hw etc/vintf etc/init lib/firmware firmware vendor_dlkm/lib/modules odm_dlkm/lib/modules odm/lib64/hw"

echo "### [1] 抽取"
if mount -o loop,ro "$IMG" "$MK" 2>/dev/null; then
  echo "  使用 loop 挂载 ✅"
  for p in $DIRS; do
    if [ -d "$MK/$p" ]; then
      mkdir -p "$D/$(dirname "$p")"
      cp -r "$MK/$p" "$D/$p" 2>/dev/null
      echo "  抽取 $p -> $(find "$D/$p" -type f 2>/dev/null | wc -l) 个文件"
    fi
  done
  umount "$MK"
else
  echo "  loop 挂载不可用，改用 debugfs 逐文件 dump"
  dump_dir() {
    local src="$1" dst="$2" n
    mkdir -p "$dst"
    debugfs -R "ls -l $src" "$IMG" 2>/dev/null | awk 'NR>2 {print $NF}' | while read -r n; do
      [ -z "$n" ] && continue
      case "$n" in .|..) continue ;; esac
      debugfs -R "dump $src/$n $dst/$n" "$IMG" >/dev/null 2>&1
    done
  }
  for p in $DIRS; do
    dump_dir "/$p" "$D/$p"
    c=$(find "$D/$p" -type f 2>/dev/null | wc -l)
    [ "$c" -gt 0 ] && echo "  $p -> $c 个文件"
  done
fi
echo "  总计: $(find "$D" -type f | wc -l) 个文件"

echo
echo "### [2] 厂商 HAL 二进制清单（/lib/hw、/lib64/hw）"
: > "$OUT/03-vendor-hal.txt"
HAL=$(find "$D" -type f -path '*hw/*' | sort)
for f in $HAL; do
  printf '%-52s %9s  %s\n' "$(basename "$f")" "$(stat -c%s "$f")" "$(file -b "$f" | cut -c1-60)" >> "$OUT/03-vendor-hal.txt"
done
wc -l < "$OUT/03-vendor-hal.txt" | xargs echo "  条目数:"

echo
echo "### [3] 内核模块 vermagic"
: > "$OUT/04-vendor-modules.txt"
MODS=$(find "$D" -type f -name '*.ko' | sort)
echo "  模块数: $(printf '%s\n' $MODS | grep -c .)"
for m in $MODS; do
  printf '%-34s %s\n' "$(basename "$m")" "$(modinfo -F vermagic "$m" 2>/dev/null || echo '(读不到)')" >> "$OUT/04-vendor-modules.txt"
done
head -30 "$OUT/04-vendor-modules.txt"

echo
echo "### [4] 下游内核私有接口引用（strings 计数）"
{
  printf '%-48s %6s %6s %6s %6s %6s\n' 二进制 kgsl ion smd mdss_fb kgsl-3d0
  for f in $(find "$D" -type f \( -name '*.so' -o -name '*.ko' \) | sort); do
    k=$(strings -a "$f" 2>/dev/null | grep -ci 'kgsl' || true)
    i=$(strings -a "$f" 2>/dev/null | grep -cE '/dev/ion|ION_IOC' || true)
    s=$(strings -a "$f" 2>/dev/null | grep -cE '/dev/smd|smd_pkt' || true)
    d=$(strings -a "$f" 2>/dev/null | grep -cE 'mdss_fb|msm_fb|/dev/graphics/fb' || true)
    fb=$(strings -a "$f" 2>/dev/null | grep -c 'kgsl-3d0' || true)
    [ "$((k + i + s + d + fb))" -gt 0 ] && printf '%-48s %6s %6s %6s %6s %6s\n' "$(basename "$f")" "$k" "$i" "$s" "$d" "$fb"
  done
} > "$OUT/05-abi-evidence.txt" 2>&1

echo
echo "### [5] 图形栈相关证据摘要"
grep -iE 'gralloc|hwcomposer|mapper|camera|memtrack|copybit' "$OUT/03-vendor-hal.txt" || true
echo "--- 接口引用（前 25 行）---"
head -25 "$OUT/05-abi-evidence.txt"

echo
echo "=== 完成 ==="
