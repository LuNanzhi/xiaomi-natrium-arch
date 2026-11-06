#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# ① 还原 system 镜像并找出内核模块（.ko）与 vermagic
# ② 扫描 vendor 的全部 .so（不限 hw 目录），统计对下游内核接口的引用
# 用法: scan-system-and-libs.sh <outdir> [ota-work 目录]
# ---------------------------------------------------------------------------
set -uo pipefail
OUT="${1:-/mnt/c/Users/Public/wsl/ota-analysis}"
W="${2:-/root/ota-work}"
SDAT=/mnt/c/Users/Public/wsl/natrium-port-src/tools/sdat2img.py
cd "$W"

echo "### [1] 还原 system 镜像"
if [ ! -f system.img ] || [ "$(stat -c%s system.img 2>/dev/null || echo 0)" -lt 1000000000 ]; then
  rm -f system.img
  python3 "$SDAT" images/system.transfer.list system.new.dat system.img 2>&1 | tail -5
fi
ls -lh system.img
dumpe2fs -h system.img 2>&1 | grep -E 'Block count|Filesystem volume' || true

echo
echo "### [2] 找 .ko（先看目录）"
for d in /lib/modules /system/lib/modules /vendor/lib/modules /odm/lib/modules; do
  n=$(debugfs -R "ls /$d" system.img 2>/dev/null | grep -cE '\.ko$' || true)
  echo "  system:$d -> $n 个 .ko"
done
debugfs -R 'ls -l /lib/modules' system.img 2>&1 | head -12

echo
echo "### [3] 挂载 system 并抽取模块"
MS=/mnt/simg; mkdir -p "$MS"
SMOD=/root/system-modules; rm -rf "$SMOD"; mkdir -p "$SMOD"
if mount -o loop,ro system.img "$MS" 2>/dev/null; then
  echo "  loop 挂载 ✅"
  for p in lib/modules system/lib/modules vendor/lib/modules; do
    [ -d "$MS/$p" ] && { mkdir -p "$SMOD/$(dirname $p)"; cp -r "$MS/$p" "$SMOD/$p"; echo "  抽取 $p: $(find "$SMOD/$p" -name '*.ko' | wc -l) 个 .ko"; }
  done
  # 顺手记一下 system 的 build.prop
  [ -f "$MS/build.prop" ] && { echo "=== system/build.prop ===" >> "$OUT/06-build-props.txt"; cat "$MS/build.prop" >> "$OUT/06-build-props.txt"; }
  umount "$MS"
else
  echo "  loop 挂载失败"
fi

echo
echo "### [4] 模块 vermagic（这就是「无法在 6.18 加载」的铁证）"
: > "$OUT/08-system-modules.txt"
find "$SMOD" -name '*.ko' | sort | while read -r m; do
  printf '%-38s %-54s %s\n' "$(basename "$m")" "$(modinfo -F vermagic "$m" 2>/dev/null || echo '(读不到)')" "$(modinfo -F srcversion "$m" 2>/dev/null)" >> "$OUT/08-system-modules.txt"
done
echo "  模块总数: $(find "$SMOD" -name '*.ko' | wc -l)"
head -40 "$OUT/08-system-modules.txt"
echo "  --- vermagic 种类统计 ---"
awk '{print $2, $3, $4}' "$OUT/08-system-modules.txt" | sort | uniq -c | sort -rn | head -5

echo
echo "### [5] vendor 全部 .so 的下游接口引用（不限 /lib/hw）"
: > "$OUT/09-vendor-libs-abi.txt"
find /root/vendor-tree -name '*.so' | sort | while read -r f; do
  k=$(strings -a "$f" 2>/dev/null | grep -ci 'kgsl' || true)
  i=$(strings -a "$f" 2>/dev/null | grep -cE '/dev/ion|ION_IOC' || true)
  s=$(strings -a "$f" 2>/dev/null | grep -cE '/dev/smd|smd_pkt' || true)
  d=$(strings -a "$f" 2>/dev/null | grep -cE 'mdss_fb|/dev/graphics/fb' || true)
  fb=$(strings -a "$f" 2>/dev/null | grep -c 'kgsl-3d0' || true)
  [ "$((k + i + s + d + fb))" -gt 0 ] && printf '%-52s %5s %5s %5s %5s %5s\n' "$(basename "$f")" "$k" "$i" "$s" "$d" "$fb"
done >> "$OUT/09-vendor-libs-abi.txt"
{
  echo "（当前抽取到的 vendor .so 数量有限，仅 /lib/hw 等目录）"
  echo "文件数: $(find /root/vendor-tree -name '*.so' | wc -l)"
} >> "$OUT/09-vendor-libs-abi.txt"
cat "$OUT/09-vendor-libs-abi.txt" | head -30

echo
echo "=== 完成 ==="
