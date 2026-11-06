#!/usr/bin/env bash
# 准备「Sharp 面板补丁内核」源码树（v6.19.5-msm8996 + td4722 面板支持）
# 注意：这步不碰 pmbootstrap 的 chroot，可与 install 并行
set -uo pipefail
TREE=/root/linux-sharp
TAG=v6.19.5-msm8996

echo "=== 1) 克隆内核源码（$TAG）==="
if [ ! -d "$TREE" ]; then
  git clone --depth 1 --branch "$TAG" https://gitlab.com/msm8996-mainline/linux.git "$TREE" 2>&1 | tail -3
else
  echo "  已存在"
fi
cd "$TREE" || exit 1
echo "  版本: $(make kernelversion 2>/dev/null || echo '?')"
echo "  HEAD: $(git log --oneline -1)"

echo
echo "=== 2) 应用 Sharp 面板补丁 ==="
bash /mnt/c/Users/Public/natrium/apply-sharp-panel.sh "$TREE" 2>&1 | tail -30

echo
echo "=== 3) 校验改动 ==="
echo "--- 驱动文件 ---"
ls -l drivers/gpu/drm/panel/panel-sharp-td4722-xcmd.c
echo "--- Kconfig ---"
grep -n -A5 'DRM_PANEL_SHARP_TD4722_XCMD' drivers/gpu/drm/panel/Kconfig | head -8
echo "--- Makefile ---"
grep -n 'td4722' drivers/gpu/drm/panel/Makefile
echo "--- DTS 面板节点 ---"
grep -n -A5 'panel: panel@0' arch/arm64/boot/dts/qcom/msm8996pro-xiaomi-natrium.dts

echo
echo "=== 4) 尝试只编译该驱动（快速语法检查）==="
export ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
if [ -f /root/art-6195/config-6.19.5-msmpmos ]; then
  cp /root/art-6195/config-6.19.5-msmpmos "$TREE/.config.sharp"
  echo "  可用参考配置: /root/art-6195/config-6.19.5-msmpmos"
fi
echo "  (完整编译留给 pmbootstrap / 后续脚本)"
df -h / | tail -1
