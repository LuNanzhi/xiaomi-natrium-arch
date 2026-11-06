#!/usr/bin/env bash
# 用 pmOS 当前官方配置编两版内核：
#   A) msm8996-mainline v6.18.7-msm8996（用户想要的 6.18）
#   B) msm8996-mainline v6.19.5-msm8996（pmOS 官方正在发布的版本，作为对照/兜底）
# 用法: build-both.sh <stage 目录>
set -uo pipefail
STAGE="${1:?用法: build-both.sh <stage>}"
CFG="$STAGE/config-postmarketos-qcom-msm8996.aarch64.current"
CROSS=aarch64-linux-gnu-
JOBS="$(nproc)"
[ -f "$CFG" ] || { echo "!! 缺少 $CFG"; exit 1; }

build_one() {
  local SRC="$1" OUT="$2" ART="$3" TAG="$4" LABEL="$5"
  echo
  echo "###############################"
  echo "### 编译 $LABEL"
  echo "###############################"
  mkdir -p "$ART"; cd "$SRC" || return 2
  rm -rf "$OUT"; mkdir -p "$OUT"
  cp "$CFG" "$OUT/.config"
  make ARCH=arm64 CROSS_COMPILE=$CROSS O="$OUT" olddefconfig >/dev/null 2>&1
  cp "$OUT/.config" "$ART/config-$TAG"
  echo "  符号数: $(grep -c '^CONFIG_' "$OUT/.config")"
  for s in CONFIG_PHY_QCOM_QMP_UFS CONFIG_PHY_QCOM_USB_HS CONFIG_SCSI_UFS_QCOM CONFIG_EXT4_FS \
           CONFIG_DRM_MSM CONFIG_ARM64_VA_BITS_48 CONFIG_QCOM_WDT CONFIG_PSTORE_RAM; do
    printf '    %-34s %s\n' "$s" "$(grep -E "^$s=" "$OUT/.config" | cut -d= -f2)"
  done
  echo "  --- 编译中 ---"
  make -j"$JOBS" ARCH=arm64 CROSS_COMPILE=$CROSS O="$OUT" Image.gz dtbs 2>&1 | tail -8
  cp "$OUT/arch/arm64/boot/Image.gz" "$ART/" || { echo "  !! 没有 Image.gz"; return 3; }
  cp "$OUT/arch/arm64/boot/dts/qcom/msm8996pro-xiaomi-natrium.dtb" "$ART/" || { echo "  !! 没有 DTB"; return 4; }
  echo "  Image.gz = $(stat -c%s "$ART/Image.gz") bytes"
  bash "$STAGE/pack-images.sh" "$STAGE" "$ART" "$TAG" "$LABEL" >/dev/null 2>&1
  ls -l "$STAGE"/boot-"$TAG"-*.img
}

echo "=== A) v6.18.7-msm8996 + pmOS 当前配置 ==="
if [ ! -d /root/linux-msm8996 ]; then
  git clone --depth 1 --branch v6.18.7-msm8996 https://gitlab.com/msm8996-mainline/linux.git /root/linux-msm8996 || exit 10
fi
build_one /root/linux-msm8996 /root/build-6187 /root/art-6187 "6.18.7-msmpmos" "6.18.7 + pmOS current config"

echo
echo "=== B) v6.19.5-msm8996（pmOS 官方版本）+ 同一配置 ==="
if [ ! -d /root/linux-6195 ]; then
  git clone --depth 1 --branch v6.19.5-msm8996 https://gitlab.com/msm8996-mainline/linux.git /root/linux-6195 || exit 20
fi
build_one /root/linux-6195 /root/build-6195 /root/art-6195 "6.19.5-msmpmos" "6.19.5 + pmOS current config"

echo
echo "=== 全部完成 ==="
ls -lh "$STAGE"/boot-6.18.7-msmpmos-*.img "$STAGE"/boot-6.19.5-msmpmos-*.img 2>/dev/null
