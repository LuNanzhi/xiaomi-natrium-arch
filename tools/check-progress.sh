#!/usr/bin/env bash
# Report live progress of the kernel build inside WSL
set -uo pipefail
SRC=/root/natrium-build/linux-6.18.55
OUT=/root/natrium-build/out
STAGE=/mnt/c/Users/Public/natrium/stage

echo "date: $(date '+%H:%M:%S')"
echo "--- source / build dirs ---"
ls -d "$SRC" "$OUT" 2>/dev/null || true
echo "--- compile progress ---"
echo "  .o files: $(find "$OUT" -name '*.o' 2>/dev/null | wc -l)"
echo "  .cmd files: $(find "$OUT" -name '.*.cmd' 2>/dev/null | wc -l)"
[ -f "$OUT/vmlinux" ] && echo "  vmlinux: $(stat -c '%s bytes %y' "$OUT/vmlinux")" || echo "  vmlinux: not yet"
[ -f "$OUT/arch/arm64/boot/Image.gz" ] && echo "  Image.gz: $(stat -c '%s bytes %y' "$OUT/arch/arm64/boot/Image.gz")" || echo "  Image.gz: not yet"
echo "--- dtbs ---"
ls -l "$OUT/arch/arm64/boot/dts/qcom/msm8996pro-xiaomi-natrium.dtb" 2>/dev/null || echo "  natrium dtb: not yet"
echo "--- packed images ---"
ls -l "$STAGE"/boot-6.18.55-ufs-*.img 2>/dev/null || echo "  none yet"
echo "--- latest make processes ---"
ps -eo etime,cmd 2>/dev/null | grep -E 'cc1|ld|make' | grep -v grep | head -5 || true
echo "--- config check (is UFS PHY built-in now?) ---"
grep -E '^CONFIG_(PHY_QCOM_QMP|PHY_QCOM_QMP_UFS|SCSI_UFS_QCOM)=' "$OUT/.config" 2>/dev/null || echo "  .config not found"
