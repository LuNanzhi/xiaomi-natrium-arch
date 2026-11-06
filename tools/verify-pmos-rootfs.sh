#!/usr/bin/env bash
# 挂载 pmOS root.img 检查内容（Phosh / 内核模块 / 固件）
set -uo pipefail
IMG=/mnt/c/Users/Public/natrium/pmos/root.img
W=/mnt/rootcheck
mkdir -p "$W"

echo "=== 挂载 root.img ($(du -h "$IMG" | cut -f1)) ==="
if mount -o loop,ro "$IMG" "$W" 2>/dev/null; then
  echo "  --- 顶层 ---"; ls "$W" | head -20
  echo "  --- os-release ---"; head -4 "$W/etc/os-release" 2>/dev/null
  echo "  --- 内核版本目录 ---"; ls "$W/lib/modules/" 2>/dev/null
  echo "  --- Sharp 面板模块是否在系统里 ---"
  find "$W/lib/modules" -name 'panel-sharp-td4722*' 2>/dev/null | head -3
  echo "  --- Phosh 是否安装 ---"
  ls -l "$W/usr/bin/phosh" 2>/dev/null || echo "    /usr/bin/phosh 未找到"
  ls -d "$W/usr/lib/phosh" 2>/dev/null && echo "    (phosh 库目录存在)"
  ls "$W/usr/share/wayland-sessions/" 2>/dev/null
  echo "  --- 设备固件 ---"; ls "$W/lib/firmware/qcom/msm8996/natrium/" 2>/dev/null
  echo "  --- deviceinfo 是否随系统 ---"; ls "$W/usr/share/deviceinfo/" 2>/dev/null | head -5
  echo "  --- 用户账户 ---"; grep -E '^user:' "$W/etc/passwd" 2>/dev/null
  umount "$W"
  echo "  (已卸载)"
else
  echo "  !! 挂载失败，用 file 看类型"
  file "$IMG"
fi
