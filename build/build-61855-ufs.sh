#!/usr/bin/env bash
# 重编 mainline 6.18.55（补上内建的 QMP UFS PHY），并打包三种镜像
# 用法: build-61855-ufs.sh <stage 目录>
set -uo pipefail
STAGE="${1:?用法: build-61855-ufs.sh <stage>}"

echo "########## 1/2 编译 6.18.55（含内建 UFS PHY）##########"
bash "$STAGE/build-kernel.sh" 6.18.55 /root/natrium-build || exit 12

echo
echo "########## 2/2 打包镜像 ##########"
bash "$STAGE/pack-images.sh" "$STAGE" /root/natrium-build/out-artifacts "6.18.55-ufs" "6.18.55 + QMP UFS PHY 内建" || exit 13

echo
echo "=== 成品 ==="
ls -lh "$STAGE"/boot-6.18.55-ufs-*.img
echo
echo "=== UFS 相关符号确认 ==="
for s in CONFIG_PHY_QCOM_QMP CONFIG_PHY_QCOM_QMP_UFS CONFIG_SCSI_UFS_QCOM CONFIG_EXT4_FS; do
  printf '  %-34s %s\n' "$s" "$(grep -E "^$s=" /root/natrium-build/out-artifacts/config-6.18-natrium | cut -d= -f2)"
done
