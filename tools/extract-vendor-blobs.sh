#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 从还原好的 vendor.img（= natrium 的 cust 分区）里抽出厂商 HAL / 内核模块，
# 产出「Android 用户态锁死 4.4 内核」的逐文件证据。
# 用法: extract-vendor-blobs.sh <vendor.img> <输出目录>
# ---------------------------------------------------------------------------
set -uo pipefail
IMG="${1:?用法: extract-vendor-blobs.sh <vendor.img> <outdir>}"
OUT="${2:-/mnt/c/Users/Public/wsl/ota-analysis}"
D=/root/vendor-tree
rm -rf "$D"; mkdir -p "$D" "$OUT"

echo "### [1] vendor 分区目录结构"
{
  echo "== image: $IMG ($(stat -c%s "$IMG") bytes) =="
  for p in / /lib /lib64 /lib/hw /lib64/hw /lib/modules /bin /bin/hw /etc /etc/vintf /firmware /lib/firmware \
           /vendor_dlkm /vendor_dlkm/lib /vendor_dlkm/lib/modules /odm_dlkm /odm_dlkm/lib/modules; do
    echo
    echo "---- debugfs ls -l $p ----"
    debugfs -R "ls -l $p" "$IMG" 2>&1 | head -40
  done
} > "$OUT/07-vendor-tree.txt" 2>&1
sed -n '1,30p' "$OUT/07-vendor-tree.txt"

echo
echo "### [2] 抽取关键目录"
for p in lib/hw lib64/hw lib/modules bin/hw etc/vintf etc/init lib/firmware firmware etc \
         vendor_dlkm/lib/modules odm_dlkm/lib/modules; do
  debugfs -R "rdump /$p $D/$(echo "$p" | tr / _)" "$IMG" >/dev/null 2>&1
done
echo "抽取文件总数: $(find "$D" -type f | wc -l)"

echo
echo "### [3] 厂商 HAL 二进制"
: > "$OUT/03-vendor-hal.txt"
HAL=$(find "$D" -type f \( -path '*hw/*' -o -name '*.so' \) 2>/dev/null | sort)
for f in $HAL; do
  printf '%-40s %-58s %s\n' "$(basename "$f")" "$(echo "$f" | sed "s|$D/||")" "$(file -b "$f" | cut -c1-52)" >> "$OUT/03-vendor-hal.txt"
done
wc -l < "$OUT/03-vendor-hal.txt" | xargs echo "  HAL/库文件数:"
head -30 "$OUT/03-vendor-hal.txt"

echo
echo "### [4] 内核模块 vermagic（决定能否在 6.18 加载）"
: > "$OUT/04-vendor-modules.txt"
MODS=$(find "$D" -type f -name '*.ko' 2>/dev/null | sort)
echo "模块数: $(printf '%s\n' $MODS | grep -c .)" | tee -a "$OUT/04-vendor-modules.txt"
for m in $MODS; do
  printf '%-32s %s\n' "$(basename "$m")" "$(modinfo -F vermagic "$m" 2>/dev/null || echo '(读不到)')" >> "$OUT/04-vendor-modules.txt"
done
head -50 "$OUT/04-vendor-modules.txt"

echo
echo "### [5] 下游内核私有接口引用（strings 计数）"
{
  printf '%-40s %6s %6s %6s %6s %6s\n' 二进制 kgsl ion smd mdss_fb fb0
  for f in $HAL $MODS; do
    [ -f "$f" ] || continue
    k=$(strings -a "$f" 2>/dev/null | grep -ci 'kgsl' || true)
    i=$(strings -a "$f" 2>/dev/null | grep -cE '/dev/ion|ION_IOC' || true)
    s=$(strings -a "$f" 2>/dev/null | grep -cE '/dev/smd|smd_pkt' || true)
    d=$(strings -a "$f" 2>/dev/null | grep -cE 'mdss_fb|msm_fb|/dev/graphics/fb' || true)
    fb=$(strings -a "$f" 2>/dev/null | grep -c 'kgsl-3d0' || true)
    [ "$((k + i + s + d + fb))" -gt 0 ] && printf '%-40s %6s %6s %6s %6s %6s\n' "$(basename "$f")" "$k" "$i" "$s" "$d" "$fb"
  done
} > "$OUT/05-abi-evidence.txt" 2>&1
cat "$OUT/05-abi-evidence.txt"

echo
echo "### [6] 关键属性"
: > "$OUT/06-build-props.txt"
for p in /etc/build.prop /build.prop /etc/prop.default /etc/vintf/manifest.xml; do
  if debugfs -R "stat $p" "$IMG" 2>/dev/null | grep -q 'Inode:'; then
    echo "=== $p ===" >> "$OUT/06-build-props.txt"
    debugfs -R "cat $p" "$IMG" >> "$OUT/06-build-props.txt" 2>/dev/null
  fi
done
grep -hE 'ro\.build\.version|ro\.product\.|ro\.hardware|ro\.board|kernel' "$OUT/06-build-props.txt" | sort -u | head -20

echo
echo "=== 完成 ==="
ls -lh "$OUT"
