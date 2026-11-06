#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 第二轮取证：把 LineageOS OTA 的 system/vendor（block-based .new.dat.br）还原成
# ext4 镜像，再用 debugfs 抽出厂商 HAL / 内核模块，产出「锁死 4.4」的逐文件证据。
#
# 用法: bash analyze-vendor-blobs.sh [工作目录(rpm 已在其中解好 images/)] [输出目录]
# ---------------------------------------------------------------------------
set -uo pipefail
W="${1:-/root/ota-work}"
OUT="${2:-/mnt/c/Users/Public/wsl/ota-analysis}"

echo "### [0] 准备依赖"
export DEBIAN_FRONTEND=noninteractive
apt-get install -y --no-install-recommends brotli android-sdk-libsparse-utils e2fsprogs python3 >/dev/null 2>&1
for c in brotli simg2img debugfs python3; do printf '  %-10s %s\n' "$c" "$(command -v $c || echo '(缺失!)')"; done

cd "$W"
# 用本工程自带的纯 Python sdat2img（不依赖联网下载）
SDAT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/sdat2img.py"
if [ ! -s sdat2img.py ]; then
  if [ -s "$SDAT" ]; then cp -f "$SDAT" sdat2img.py; else
    wget -q -O sdat2img.py https://raw.githubusercontent.com/xpirt/sdat2img/master/sdat2img.py || true
  fi
fi
echo "  sdat2img.py: $(wc -l < sdat2img.py 2>/dev/null || echo 0) 行（来自 $( [ -s "$SDAT" ] && echo 本工程 || echo 网络 )）"
if [ ! -s sdat2img.py ]; then echo "!! 没有可用的 sdat2img，退出"; exit 1; fi

# dat.br -> dat -> img
build_img() {   # build_img <名字>
  local n="$1"
  local br="images/$n.new.dat.br" tl="images/$n.transfer.list" dat="$n.new.dat" img="$n.img"
  echo "### [$n] 还原镜像"
  [ -f "$br" ] || { echo "  缺 $br"; return 1; }
  if [ ! -f "$dat" ]; then
    brotli -d -f -k -o "$dat" "$br" || { echo "  brotli 解压失败"; return 1; }
  fi
  echo "  dat 大小: $(stat -c%s "$dat") bytes"
  if [ ! -f "$img" ]; then
    python3 sdat2img.py "$tl" "$dat" "$img" 2>&1 | tail -3 || { echo "  sdat2img 失败"; return 1; }
  fi
  echo "  img 大小: $(stat -c%s "$img") bytes"
  # sdat2img 输出可能是 sparse，再转一次 raw
  if [ "$(xxd -p -l4 "$img")" = "3aff26ed" ]; then
    simg2img "$img" "$img.raw" && img="$img.raw"
  fi
  # ext4 判定
  local m
  m=$(xxd -p -s 1080 -l 2 "$img")
  echo "  ext4 magic @0x438 = 0x$m  $([ "$m" = "53ef" ] && echo '(ext4 ✅)' || echo '(不是 ext4?)')"
  echo "$img"
}

for n in vendor system; do
  img=$(build_img "$n" | tail -1)
  [ -f "$img" ] || continue
  d="$W/tree-$n"; rm -rf "$d"; mkdir -p "$d"
  echo "### [$n] 目录清单（debugfs）"
  for p in /lib/hw /lib64/hw /lib/modules /etc /lib/firmware; do
    if debugfs -R "ls -l $p" "$img" >/dev/null 2>&1; then
      cnt=$(debugfs -R "ls -l $p" "$img" 2>/dev/null | grep -c '^ *[0-9]')
      echo "  $p  存在，$cnt 个条目"
      debugfs -R "rdump $p $d/$(echo "$p" | tr / _)" "$img" >/dev/null 2>&1
    else
      echo "  $p  不存在"
    fi
  done
  # build.prop
  for bp in /build.prop /system/build.prop /etc/build.prop; do
    if debugfs -R "stat $bp" "$img" >/dev/null 2>&1; then
      echo "  === $n:$bp ===" >> "$OUT/06-build-props.txt"
      debugfs -R "cat $bp" "$img" >> "$OUT/06-build-props.txt" 2>/dev/null
    fi
  done
done

echo
echo "### [A] 厂商 HAL 二进制清单"
: > "$OUT/03-vendor-hal.txt"
HAL=$(find "$W"/tree-* -type f \( -path '*lib/hw/*' -o -path '*lib64/hw/*' \) 2>/dev/null | sort)
echo "$HAL" | while read -r f; do
  [ -f "$f" ] || continue
  printf '%-34s %-26s %s\n' "$(basename "$f")" "$(dirname "$f" | sed "s|$W/||")" "$(file -b "$f" | cut -c1-60)" >> "$OUT/03-vendor-hal.txt"
done
cat "$OUT/03-vendor-hal.txt"

echo
echo "### [B] 内核模块 vermagic"
: > "$OUT/04-vendor-modules.txt"
MODS=$(find "$W"/tree-* -type f -name '*.ko' 2>/dev/null | sort)
echo "模块总数: $(printf '%s\n' $MODS | grep -c . )" | tee -a "$OUT/04-vendor-modules.txt"
for m in $MODS; do
  printf '%-30s %s\n' "$(basename "$m")" "$(modinfo -F vermagic "$m" 2>/dev/null || echo '(无法读取)')" >> "$OUT/04-vendor-modules.txt"
done
head -40 "$OUT/04-vendor-modules.txt"

echo
echo "### [C] 下游内核接口引用（逐个二进制的 strings 计数）"
{
  printf '%-40s %6s %6s %6s %6s\n' 二进制 kgsl ion smd mdss_fb
  for f in $HAL $MODS; do
    [ -f "$f" ] || continue
    k=$(strings -a "$f" | grep -ci 'kgsl' || true)
    i=$(strings -a "$f" | grep -cE '/dev/ion|ION_IOC' || true)
    s=$(strings -a "$f" | grep -cE '/dev/smd|smd_pkt' || true)
    d=$(strings -a "$f" | grep -cE 'mdss_fb|msm_fb|/dev/graphics/fb' || true)
    [ "$((k + i + s + d))" -gt 0 ] && printf '%-40s %6s %6s %6s %6s\n' "$(basename "$f")" "$k" "$i" "$s" "$d"
  done
} > "$OUT/05-abi-evidence.txt" 2>&1
cat "$OUT/05-abi-evidence.txt"

echo
echo "### [D] 属性摘要"
grep -hE 'ro\.build\.version|ro\.product\.(device|model)|ro\.hardware|ro\.board|ro\.vendor' "$OUT/06-build-props.txt" 2>/dev/null | sort -u | head -25

echo
echo "=== 完成 ==="; ls -lh "$OUT"
