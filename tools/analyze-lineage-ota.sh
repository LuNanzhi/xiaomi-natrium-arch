#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 用你自己的 LineageOS OTA 包做取证分析：把「Android 用户态为何锁死 4.4 内核」
# 变成逐文件可验证的事实（而不是我的断言）。
#
# 用法(在 WSL 内): bash analyze-lineage-ota.sh <ota.zip 路径> [输出目录]
#
# 产出:
#   01-filelist.txt        OTA 包内容清单（顺便看有没有 dtbo.img）
#   02-images.txt          解出的镜像与格式判定
#   03-vendor-hal.txt      厂商 HAL 二进制清单 + ELF 架构
#   04-vendor-modules.txt  内核模块 vermagic（能否在 6.18 加载）
#   05-abi-evidence.txt     HAL/模块里对下游内核接口的引用计数(kgsl/ion/smd/msm_fb)
#   06-build-props.txt     系统/vendor 属性（Android 版本、内核期望）
#   ANALYSIS.md            汇总报告
# ---------------------------------------------------------------------------
set -uo pipefail

ZIP_SRC="${1:?用法: analyze-lineage-ota.sh <ota.zip> [outdir]}"
OUT="${2:-/mnt/c/Users/Public/wsl/ota-analysis}"
W=/root/ota-work
mkdir -p "$W" "$OUT"

echo "### [0] 准备"
cp -f "$ZIP_SRC" "$W/ota.zip" 2>/dev/null || true
cd "$W"
ls -lh ota.zip

echo "### [1] OTA 内容清单"
unzip -l ota.zip > "$OUT/01-filelist.txt" 2>&1
tail -40 "$OUT/01-filelist.txt"
grep -iE 'dtbo|vbmeta|boot\.img|recovery' "$OUT/01-filelist.txt" || true

echo "### [2] 解出镜像"
rm -rf images; mkdir -p images
unzip -o ota.zip -d images '*.img' > "$OUT/02-images.txt" 2>&1
unzip -o ota.zip -d images '*.new.dat*' '*.transfer.list' >> "$OUT/02-images.txt" 2>&1
unzip -o ota.zip -d images 'META-INF/*' >> "$OUT/02-images.txt" 2>&1
ls -lh images/ | tee -a "$OUT/02-images.txt"

# 需要 sparse / brotli / sdat2img 支持时按需安装（Ubuntu universe，很小）
if ! command -v simg2img >/dev/null 2>&1 || ! command -v brotli >/dev/null 2>&1; then
  echo "  (安装 simg2img / brotli)"
  (apt-get install -y --no-install-recommends android-sdk-libsparse-utils brotli >/dev/null 2>&1) || true
fi

# 若是 system.new.dat.br + system.transfer.list 形式，还原成 system.img
for br in images/*.new.dat.br; do
  [ -f "$br" ] || continue
  base="${br%.new.dat.br}"
  echo "  发现 dat 形式: $(basename "$br")，用 sdat2img 还原" | tee -a "$OUT/02-images.txt"
  command -v brotli >/dev/null 2>&1 && brotli -d -f -k "$br" -o "$base.new.dat" 2>/dev/null
  if [ ! -f sdat2img.py ]; then
    wget -q -O sdat2img.py https://raw.githubusercontent.com/xpirt/sdat2img/master/sdat2img.py || true
  fi
  if [ -f sdat2img.py ] && [ -f "$base.transfer.list" ]; then
    python3 sdat2img.py "$base.transfer.list" "$base.new.dat" "$base.img" >/dev/null 2>&1 || true
  fi
done

# sparse(.img) / br(.new.dat.br) → raw
raw_of() {  # raw_of <文件>  -> 回声 raw 路径
  local f="$1" out="$1.raw"
  [ -f "$out" ] && { echo "$out"; return; }
  case "$f" in
    *.br)  brotli -d -c "$f" > "${f%.br}" 2>/dev/null; f="${f%.br}" ;;
  esac
  if [ "$(xxd -p -l4 "$f" 2>/dev/null)" = "3aff26ed" ]; then
    if command -v simg2img >/dev/null 2>&1; then simg2img "$f" "$out" 2>/dev/null; else echo ""; return; fi
  else
    cp -f "$f" "$out" 2>/dev/null
  fi
  echo "$out"
}

echo "### [3] 逐个镜像做格式判定与内容提取"
: > "$OUT/03-vendor-hal.txt"
: > "$OUT/04-vendor-modules.txt"
: > "$OUT/06-build-props.txt"
VROOT="$W/vtree"
rm -rf "$VROOT"; mkdir -p "$VROOT"

for img in images/*.img; do
  [ -f "$img" ] || continue
  sz=$(stat -c%s "$img")
  magic=$(xxd -p -l4 "$img")
  kind="ext4/raw"
  [ "$magic" = "3aff26ed" ] && kind="sparse"
  echo "  $(basename "$img"): $sz bytes, magic=$magic ($kind)" | tee -a "$OUT/02-images.txt"
  raw=$(raw_of "$img")
  [ -n "$raw" ] && [ -f "$raw" ] || { echo "    !! 无法转成 raw" | tee -a "$OUT/02-images.txt"; continue; }
  # file 判定
  file "$raw" | tee -a "$OUT/02-images.txt"

  name=$(basename "$img" .img)
  dest="$VROOT/$name"
  mkdir -p "$dest"
  # 用 debugfs 列出根目录，找出 lib/hw、lib64/hw、lib/modules
  for d in lib/hw lib64/hw lib/modules etc; do
    if debugfs -R "ls -l /$d" "$raw" >/dev/null 2>&1; then
      echo "  [$name] 含 /$d" | tee -a "$OUT/02-images.txt"
      debugfs -R "rdump /$d $dest/$(echo "$d" | tr / _)" "$raw" >/dev/null 2>&1 || true
    fi
  done
  # build.prop
  for p in /system/build.prop /build.prop /etc/build.prop; do
    if debugfs -R "stat $p" "$raw" >/dev/null 2>&1; then
      echo "  === $name:$p ===" >> "$OUT/06-build-props.txt"
      debugfs -R "cat $p" "$raw" >> "$OUT/06-build-props.txt" 2>/dev/null || true
    fi
  done
done

echo "### [4] 厂商 HAL 清单"
HAL=$(find "$VROOT" -type f \( -path '*lib/hw/*' -o -path '*lib64/hw/*' \) 2>/dev/null | sort)
echo "$HAL" | tee -a "$OUT/03-vendor-hal.txt"
for f in $HAL; do
  printf '%-70s %s\n' "$(basename "$f")" "$(file -b "$f" | cut -c1-70)" >> "$OUT/03-vendor-hal.txt"
done

echo "### [5] 内核模块 vermagic"
MODS=$(find "$VROOT" -type f -name '*.ko' 2>/dev/null | sort)
echo "共 $(echo "$MODS" | grep -c . ) 个模块" | tee -a "$OUT/04-vendor-modules.txt"
for m in $MODS; do
  printf '%-34s %s\n' "$(basename "$m")" "$(modinfo -F vermagic "$m" 2>/dev/null || echo '(无 vermagic)')" >> "$OUT/04-vendor-modules.txt"
done
head -40 "$OUT/04-vendor-modules.txt"

echo "### [6] 下游内核接口引用计数（关键证据）"
{
  echo "# 对下游内核私有接口的引用（strings 计数）"
  echo
  printf '%-46s %6s %6s %6s %6s %6s\n' 文件 kgsl ion smd mdss_fb fb0
  for f in $HAL $MODS; do
    [ -f "$f" ] || continue
    b=$(basename "$f")
    echo "$b" | grep -qE '\.so$|\.ko$' || continue
    k=$(strings -a "$f" 2>/dev/null | grep -c -i 'kgsl'                  || true)
    i=$(strings -a "$f" 2>/dev/null | grep -c -E '/dev/ion|ION_IOC'      || true)
    s=$(strings -a "$f" 2>/dev/null | grep -c -E '/dev/smd|smd_pkt'      || true)
    d=$(strings -a "$f" 2>/dev/null | grep -c -E 'mdss_fb|msm_fb|/dev/graphics/fb' || true)
    fb=$(strings -a "$f" 2>/dev/null | grep -c -E 'kgsl-3d0'            || true)
    [ "$((k+i+s+d+fb))" -gt 0 ] && printf '%-46s %6s %6s %6s %6s %6s\n' "$b" "$k" "$i" "$s" "$d" "$fb"
  done
} > "$OUT/05-abi-evidence.txt" 2>&1
cat "$OUT/05-abi-evidence.txt"

echo "### [7] 汇总报告"
{
  echo "# LineageOS OTA 取证分析（$(date '+%F %T')）"
  echo
  echo "输入: $ZIP_SRC"
  echo
  echo "## 1. OTA 包结构"
  echo '```'; grep -E '\.img|\.dat|dtbo|vbmeta|\.ko|build.prop' "$OUT/01-filelist.txt" | head -40; echo '```'
  echo
  echo "## 2. 厂商 HAL 二进制（Android 图形/相机等 HAL，编译期绑定下游内核）"
  echo '```'; cat "$OUT/03-vendor-hal.txt"; echo '```'
  echo
  echo "## 3. 内核模块 vermagic（决定能否在 6.18 加载）"
  echo '```'; cat "$OUT/04-vendor-modules.txt"; echo '```'
  echo
  echo "## 4. 下游内核私有接口引用计数（这是"不可行"的直接证据）"
  echo '```'; cat "$OUT/05-abi-evidence.txt"; echo '```'
  echo
  echo "## 5. 系统属性"
  echo '```'; grep -hE 'ro\.build\.version|ro\.product\.(device|model)|ro\.hardware|ro\.board' "$OUT/06-build-props.txt" | sort -u | head -30; echo '```'
} > "$OUT/ANALYSIS.md" 2>&1

echo
echo "=== 完成，报告: $OUT/ANALYSIS.md ==="
ls -lh "$OUT"
