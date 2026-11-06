#!/usr/bin/env bash
# 在内核源码里定位 UFS 报错的确切位置与原因
set -uo pipefail
TREE=/root/linux-sharp

echo "=== 1) 搜索报错字符串 ==="
for s in "failed to find hw" "failed to find vendor" "unexpected irq"; do
  echo "--- \"$s\" ---"
  grep -rn --include=*.c --include=*.h "$s" "$TREE/drivers/ufs" "$TREE/drivers/phy" 2>/dev/null | head -8
done

echo
echo "=== 2) ufs-qcom 里读 hw 版本/厂商的代码 ==="
F=$(find "$TREE/drivers/ufs" -name 'ufs-qcom.c' | head -1)
echo "  文件: $F"
[ -n "$F" ] && grep -n -B6 -A18 'failed to find hw\|ver_str\|get_hw_version\|vendor' "$F" | head -60

echo
echo "=== 3) natrium 设备树里的 UFS 节点 ==="
DTS="$TREE/arch/arm64/boot/dts/qcom/msm8996pro-xiaomi-natrium.dts"
COMMON="$TREE/arch/arm64/boot/dts/qcom/msm8996-xiaomi-common.dtsi"
for f in "$DTS" "$COMMON"; do
  [ -f "$f" ] || continue
  echo "--- $(basename "$f") ---"
  grep -n -A22 'ufshc@624000\|ufsphy\|ufs_phy' "$f" | head -50
done

echo
echo "=== 4) msm8996.dtsi 里的 UFS/UFS-PHY 定义 ==="
DT="$TREE/arch/arm64/boot/dts/qcom/msm8996.dtsi"
grep -n -A28 'ufshc: ufs@624000\|ufsphy' "$DT" | head -70

echo
echo "=== 5) 内核配置里的 UFS/PHY 相关项（我们实际用的配置）==="
CFG=/root/pmaports/device/testing/linux-postmarketos-qcom-msm8996/config-postmarketos-qcom-msm8996.aarch64
grep -E 'CONFIG_(SCSI_UFS|PHY_QCOM|QCOM_ICE|SCSI_UFS_QCOM|UFS_QCOM)' "$CFG" | head -20
