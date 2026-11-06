#!/usr/bin/env bash
# 用 pmOS 官方 config 重编 mainline 6.18.55（源码已在 /root/natrium-build/linux-6.18.55）
# 用法: build-pmosconf.sh <stage 目录>
set -uo pipefail
STAGE="${1:?用法: build-pmosconf.sh <stage>}"
SRC=/root/natrium-build/linux-6.18.55
OUT=/root/natrium-build/out-pmos
ART=/root/natrium-build/art-pmos
CROSS=aarch64-linux-gnu-
JOBS="$(nproc)"
mkdir -p "$ART"
cd "$SRC"

echo "### [1] 用 pmOS 官方 config 覆盖 .config"
rm -rf "$OUT"; mkdir -p "$OUT"
cp "$STAGE/config-postmarketos-qcom-msm8996.aarch64" "$OUT/.config"
make ARCH=arm64 CROSS_COMPILE=$CROSS O="$OUT" olddefconfig >/dev/null 2>&1
cp "$OUT/.config" "$ART/config-6.18.55-pmos"
echo "  符号数: $(grep -c '^CONFIG_' "$OUT/.config")"

echo
echo "### [2] 关键符号核对"
for s in CONFIG_PHY_QCOM_QMP CONFIG_PHY_QCOM_QMP_UFS CONFIG_SCSI_UFS_QCOM CONFIG_EXT4_FS \
         CONFIG_PHY_QCOM_USB_HS CONFIG_PHY_QCOM_USB_SS CONFIG_PHY_QCOM_USB_SNPS_FEMTO_V2 \
         CONFIG_USB_DWC3 CONFIG_USB_CONFIGFS CONFIG_USB_GADGET \
         CONFIG_DRM_MSM CONFIG_DRM_PANEL_JDI_R63452 CONFIG_DRM_FBDEV_EMULATION CONFIG_FRAMEBUFFER_CONSOLE \
         CONFIG_RMI4_I2C CONFIG_PINCTRL_MSM8996 CONFIG_MSM_GCC_8996 \
         CONFIG_QCOM_SMD_RPM CONFIG_REGULATOR_QCOM_SMD_RPM CONFIG_ARM64_VA_BITS_48 CONFIG_QCOM_WDT; do
  printf '  %-42s %s\n' "$s" "$(grep -E "^$s=" "$OUT/.config" | cut -d= -f2)"
done

echo
echo "### [3] 编译 Image.gz + dtbs（约 10~15 分钟）"
make -j"$JOBS" ARCH=arm64 CROSS_COMPILE=$CROSS O="$OUT" Image.gz dtbs 2>&1 | tail -12

echo
echo "### [4] 收集产物"
cp "$OUT/arch/arm64/boot/Image.gz" "$ART/" || { echo "!! 没有 Image.gz"; exit 3; }
DTB="$OUT/arch/arm64/boot/dts/qcom/msm8996pro-xiaomi-natrium.dtb"
[ -f "$DTB" ] || { echo "!! 没有 natrium DTB"; exit 4; }
cp "$DTB" "$ART/"
ls -l "$ART"
python3 - "$ART/Image.gz" <<'PY'
import gzip, sys
raw = gzip.decompress(open(sys.argv[1], "rb").read())
i = raw.find(b"Linux version")
print("  内核版本串:", raw[i:i+140].split(b"\x00")[0].decode("utf-8", "replace") if i >= 0 else "未找到")
PY

echo
echo "### [5] 打包镜像"
bash "$STAGE/pack-images.sh" "$STAGE" "$ART" "6.18.55-pmos" "6.18.55 + pmOS official config" || exit 5
echo
ls -lh "$STAGE"/boot-6.18.55-pmos-*.img
