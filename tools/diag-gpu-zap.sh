#!/usr/bin/env bash
# 检查 GPU zap shader 的固件路径是否匹配（黑屏的常见原因：Path 不一致导致 Adreno 起不来 → Phosh 无法启动）
set -uo pipefail
T=/root/linux-sharp
R=/mnt/rootcheck

echo "=== 1) 内核源码里请求 GPU 固件的路径 ==="
grep -rn 'a530_zap\|zap_shader\|zap-shader' "$T/drivers/gpu/drm/msm" 2>/dev/null | head -15

echo
echo "=== 2) mainline 设备树里的 zap-shader 节点 ==="
grep -rn -B4 -A10 'zap-shader\|zap_shader' "$T/arch/arm64/boot/dts/qcom/msm8996.dtsi" "$T/arch/arm64/boot/dts/qcom/msm8996-xiaomi-common.dtsi" "$T/arch/arm64/boot/dts/qcom/msm8996pro-xiaomi-natrium.dts" 2>/dev/null | head -40

echo
echo "=== 3) 我们刷进去的 rootfs 里固件实际路径 ==="
IMG=/mnt/c/Users/Public/natrium/pmos/root.img
mkdir -p "$R"
if mount -o loop,ro "$IMG" "$R" 2>/dev/null; then
  echo "  --- a530* 在哪 ---"
  find "$R/lib/firmware" -name 'a530*' 2>/dev/null
  echo "  --- natrium 固件目录 ---"
  ls "$R/lib/firmware/qcom/msm8996/natrium/" 2>/dev/null
  echo "  --- linux-firmware-qcom 提供的 qcom 顶层文件（前 20）---"
  ls "$R/lib/firmware/qcom/" 2>/dev/null | head -20
  echo "  --- 面板模块 ---"
  find "$R/lib/modules" -name 'panel-sharp*' 2>/dev/null
  echo "  --- DRM/相机的固件路径惯例 ---"
  ls "$R/lib/firmware/" 2>/dev/null | head -10
  umount "$R"
else
  echo "  !! 挂载失败"
fi

echo
echo "=== 4) 对比：pmOS 固件包安装路径 vs 内核期望路径 ==="
grep -rn 'firmware-name' "$T/arch/arm64/boot/dts/qcom/msm8996pro-xiaomi-natrium.dts" "$T/arch/arm64/boot/dts/qcom/msm8996-xiaomi-common.dtsi" 2>/dev/null | head -10
