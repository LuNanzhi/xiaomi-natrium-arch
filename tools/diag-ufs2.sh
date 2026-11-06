#!/usr/bin/env bash
# 查 UFS 控制器在 natrium 上是否被启用、依赖是否齐备
set -uo pipefail
T=/root/linux-sharp
D=$T/arch/arm64/boot/dts/qcom

echo "=== 1) 哪些 dts 启用了 &ufshc / &ufsphy ==="
grep -rn '&ufshc' "$D" | head -10
echo "  ---"
grep -rn -A4 '&ufshc {' "$D"/msm8996*.dtsi "$D"/msm8996*.dts 2>/dev/null | head -30

echo
echo "=== 2) natrium 的完整 DTS 包含链 ==="
head -30 "$D/msm8996pro-xiaomi-natrium.dts"
echo "  --- common 里启用 UFS 的片段 ---"
grep -n -B2 -A8 'ufs' "$D/msm8996-xiaomi-common.dtsi" | head -40

echo
echo "=== 3) ufsphy 节点全文（msm8996.dtsi）==="
sed -n '2168,2215p' "$D/msm8996.dtsi"

echo
echo "=== 4) ufshc 节点全文 ==="
sed -n '2100,2168p' "$D/msm8996.dtsi"

echo
echo "=== 5) 配置里 UFS/ICE/PHY 的完整清单 ==="
CFG=/root/pmaports/device/testing/linux-postmarketos-qcom-msm8996/config-postmarketos-qcom-msm8996.aarch64
grep -nE 'UFS|QCOM_ICE|ICE' "$CFG" | head -20

echo
echo "=== 6) ufs-qcom 驱动里 -517/时钟相关的失败点 ==="
F="$T/drivers/ufs/host/ufs-qcom.c"
grep -n -B4 -A12 'ufs_qcom_clk_scale_notify\|deferred\|EPROBE_DEFER' "$F" | head -40
echo "  --- 探针失败时的报错字符串 ---"
grep -n 'dev_err' "$F" | head -25
