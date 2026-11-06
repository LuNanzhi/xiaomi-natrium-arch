#!/usr/bin/env bash
# Progress of the pmOS-config build
set -uo pipefail
OUT=/root/natrium-build/out-pmos
ART=/root/natrium-build/art-pmos
STAGE=/mnt/c/Users/Public/natrium/stage

echo "time: $(date '+%H:%M:%S')"
[ -d "$OUT" ] || { echo "build dir missing"; exit 0; }
echo "objects compiled : $(find "$OUT" -name '*.o' 2>/dev/null | wc -l)"
[ -f "$OUT/vmlinux" ] && echo "vmlinux         : $(stat -c%s "$OUT/vmlinux") bytes" || echo "vmlinux         : not yet"
[ -f "$OUT/arch/arm64/boot/Image.gz" ] && echo "Image.gz        : $(stat -c%s "$OUT/arch/arm64/boot/Image.gz") bytes" || echo "Image.gz        : not yet"
[ -f "$OUT/arch/arm64/boot/dts/qcom/msm8996pro-xiaomi-natrium.dtb" ] && echo "natrium dtb     : built" || echo "natrium dtb     : not yet"
echo "artifacts dir   : $(ls "$ART" 2>/dev/null | tr '\n' ' ')"
echo "packed images   : $(ls "$STAGE"/boot-6.18.55-pmos-*.img 2>/dev/null | xargs -r -n1 basename | tr '\n' ' ')"
echo "--- running make ---"
ps -eo etime,cmd | grep -E 'make .*(Image.gz|dtbs)' | grep -v grep | head -3
echo "--- key config symbols in this build ---"
for s in CONFIG_PHY_QCOM_QMP_UFS CONFIG_PHY_QCOM_USB_HS CONFIG_SCSI_UFS_QCOM CONFIG_DRM_MSM CONFIG_DRM_PANEL_JDI_R63452 CONFIG_ARM64_VA_BITS_48 CONFIG_QCOM_WDT; do
  printf '  %-36s %s\n' "$s" "$(grep -E "^$s=" "$OUT/.config" 2>/dev/null | cut -d= -f2)"
done
