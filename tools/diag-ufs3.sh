#!/usr/bin/env bash
# 决定性问题：UFS 驱动是内建还是模块？initramfs 里有没有它？
set -uo pipefail
WORK=/root/.local/var/pmbootstrap
NAT=/mnt/c/Users/Public/natrium
APK=$(ls -S "$WORK"/packages/edge/aarch64/linux-postmarketos-qcom-msm8996-*.apk 2>/dev/null | head -1)
W=/tmp/kpkg; rm -rf "$W"; mkdir -p "$W"

echo "=== 1) 内核包: $(basename "$APK") ==="
cd "$W"
tar -xzf "$APK" 2>/dev/null || cp "$APK" . && { gzip -dc "$APK" > k.tar 2>/dev/null && tar -xf k.tar 2>/dev/null; }
ls | head -10

echo
echo "=== 2) 包里的 UFS 模块 ==="
find . -path '*ufs*' -name '*.ko*' 2>/dev/null | head -10
echo "  (若为空 = UFS 驱动为内建)"

echo
echo "=== 3) 包里的内核配置 ==="
CFG=$(find . -name 'config-*' 2>/dev/null | head -1)
echo "  config: $CFG"
if [ -n "$CFG" ]; then
  for s in CONFIG_SCSI_UFSHCD CONFIG_SCSI_UFSHCD_PLATFORM CONFIG_SCSI_UFS_QCOM CONFIG_PHY_QCOM_QMP_UFS CONFIG_PHY_QCOM_QMP CONFIG_QCOM_ICE CONFIG_REGULATOR_QCOM_SMD_RPM CONFIG_QCOM_CLK_SMD_RPM CONFIG_SCSI_UFS_CRYPTO; do
    grep -E "^(# )?$s(=| is not set)" "$CFG" || echo "  $s  (未出现)"
  done
fi

echo
echo "=== 4) initramfs 里的模块清单（/lib/modules）==="
cd /tmp/irdump 2>/dev/null || exit 0
echo "  --- /lib/modules 内容 ---"
find lib/modules -maxdepth 2 2>/dev/null | head -20
echo "  --- initramfs.load ---"
cat lib/modules/initramfs.load 2>/dev/null
echo "  --- 所有 .ko（含 zst）---"
find lib/modules -name '*.ko*' 2>/dev/null | sed 's|.*/||' | sort | head -40
echo "  --- 是否有 ufs ---"
find lib/modules -iname '*ufs*' 2>/dev/null | head

echo
echo "=== 5) 我们的设备包 modules-initfs 现状 ==="
cat /root/pmaports/device/archived/device-xiaomi-natrium/modules-initfs
