#!/usr/bin/env bash
# 全量扫描 vendor 分区的 .so，统计对下游内核私有接口的引用（kgsl / ion / smd / mdss_fb）
set -uo pipefail
IMG="${1:-/root/ota-work/vendor.img}"
OUT="${2:-/mnt/c/Users/Public/wsl/ota-analysis}"
D=/root/vendor-full
MK=/mnt/vimg
rm -rf "$D"; mkdir -p "$D" "$MK"

echo "### [1] 挂载 vendor 并复制全部库目录"
if ! mount -o loop,ro "$IMG" "$MK" 2>/dev/null; then echo "挂载失败"; exit 1; fi
for p in lib lib64 bin etc app overlay odm odm_dlkm radio rfs usr; do
  [ -e "$MK/$p" ] && { mkdir -p "$D"; cp -r "$MK/$p" "$D/" 2>/dev/null; }
done
umount "$MK"
echo "  复制完成: $(du -sh "$D" | cut -f1), 文件 $(find "$D" -type f | wc -l)"

echo
echo "### [2] 全量统计（只列出有命中的）"
: > "$OUT/09-vendor-libs-abi.txt"
{
  printf '%-56s %5s %5s %5s %5s\n' 文件 kgsl ion smd mdss_fb
  find "$D" -name '*.so' | sort | while read -r f; do
    k=$(strings -a "$f" 2>/dev/null | grep -ci 'kgsl' || true)
    i=$(strings -a "$f" 2>/dev/null | grep -cE '/dev/ion|ION_IOC' || true)
    s=$(strings -a "$f" 2>/dev/null | grep -cE '/dev/smd|smd_pkt' || true)
    d=$(strings -a "$f" 2>/dev/null | grep -cE 'mdss_fb|/dev/graphics/fb' || true)
    [ "$((k + i + s + d))" -gt 0 ] && printf '%-56s %5s %5s %5s %5s\n' "$(basename "$f")" "$k" "$i" "$s" "$d"
  done
} >> "$OUT/09-vendor-libs-abi.txt"
head -45 "$OUT/09-vendor-libs-abi.txt"

echo
echo "### [3] 汇总统计"
{
  echo
  echo "== 汇总（$(date '+%F %T')）=="
  echo "vendor 分区 .so 总数: $(find "$D" -name '*.so' | wc -l)"
  echo "命中任一接口的库数: $(($(wc -l < "$OUT/09-vendor-libs-abi.txt") - 1))"
  for k in kgsl ion smd mdss_fb; do
    col=$(grep -v '^文件' "$OUT/09-vendor-libs-abi.txt" | awk -v k="$k" 'NR==1{for(i=1;i<=NF;i++) if($i==k) c=i} {if($c+0>0) n++} END{print n+0}')
    echo "  引用 $k 的库数: $col"
  done
  echo
  echo "== 关键库点名 =="
  for n in libgsl.so libadreno_utils.so libllvm-glnext.so libril-qc-qmi-1.so libwifi-hal-qcacld.so libwifi-hal.so libqti_performance.so libqdMetaData.so vendor.qti.hardware.display.allocator-service android.hardware.graphics.allocator; do
    grep -i -- "$n" "$OUT/09-vendor-libs-abi.txt" | head -2
  done
} | tee -a "$OUT/09-vendor-libs-abi.txt"

echo
echo "### [4] 全盘找 .ko（确认这个 ROM 到底有没有可加载模块）"
find "$D" -name '*.ko' | head -20
echo "  .ko 数量: $(find "$D" -name '*.ko' | wc -l)"

echo
echo "=== 完成 ==="
