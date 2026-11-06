#!/usr/bin/env bash
# 编译指定版本的 msm8996-mainline 内核（用 pmOS 当前官方配置），用于找出“最后一个能启动的版本”
# 用法: build-tags.sh <stage 目录> <版本号...>    例如: build-tags.sh /stage 6.17.8 6.12.10
set -uo pipefail
STAGE="${1:?用法: build-tags.sh <stage> <tag...>}"
shift
CFG="$STAGE/config-postmarketos-qcom-msm8996.aarch64.current"
CROSS=aarch64-linux-gnu-
JOBS="$(nproc)"
[ -f "$CFG" ] || { echo "!! 缺少 $CFG"; exit 1; }

build_one() {
  local SRC="$1" OUT="$2" ART="$3" TAG="$4" LABEL="$5"
  echo
  echo "###############################"
  echo "### $LABEL"
  echo "###############################"
  mkdir -p "$ART"
  cd "$SRC" || return 2
  rm -rf "$OUT"; mkdir -p "$OUT"
  cp "$CFG" "$OUT/.config"
  make ARCH=arm64 CROSS_COMPILE=$CROSS O="$OUT" olddefconfig >/dev/null 2>&1
  cp "$OUT/.config" "$ART/config-$TAG"
  echo "  符号数: $(grep -c '^CONFIG_' "$OUT/.config")"
  make -j"$JOBS" ARCH=arm64 CROSS_COMPILE=$CROSS O="$OUT" Image.gz dtbs 2>&1 | tail -6
  cp "$OUT/arch/arm64/boot/Image.gz" "$ART/" || { echo "  !! 没有 Image.gz"; return 3; }
  cp "$OUT/arch/arm64/boot/dts/qcom/msm8996pro-xiaomi-natrium.dtb" "$ART/" || { echo "  !! 没有 natrium DTB"; return 4; }
  echo "  Image.gz = $(stat -c%s "$ART/Image.gz") bytes"
  python3 - "$ART/Image.gz" <<'PY'
import gzip, sys
raw = gzip.decompress(open(sys.argv[1], "rb").read())
i = raw.find(b"Linux version")
print("  版本串:", raw[i:i+120].split(b"\x00")[0].decode("utf-8", "replace") if i >= 0 else "未找到")
PY
  bash "$STAGE/pack-images.sh" "$STAGE" "$ART" "$TAG" "$LABEL" >/dev/null 2>&1
  ls -l "$STAGE"/boot-"$TAG"-logger.img 2>/dev/null
}

for V in "$@"; do
  DIR="/root/linux-$V"
  if [ ! -d "$DIR" ]; then
    echo "=== 克隆 msm8996-mainline v$V-msm8996 ==="
    git clone --depth 1 --branch "v$V-msm8996" https://gitlab.com/msm8996-mainline/linux.git "$DIR" || { echo "  !! 克隆失败，跳过"; continue; }
  fi
  build_one "$DIR" "/root/build-$V" "/root/art-$V" "$V-msm" "v$V-msm8996 + pmOS current config"
done

echo
echo "=== 全部完成 ==="
ls -lh "$STAGE"/boot-*-msm-logger.img 2>/dev/null
