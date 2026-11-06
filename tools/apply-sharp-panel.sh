#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 把 Sharp TD4722 面板支持前移到现代内核（v6.19.5-msm8996）
#   改动 1: 新增驱动 drivers/gpu/drm/panel/panel-sharp-td4722-xcmd.c
#   改动 2: drivers/gpu/drm/panel/Kconfig 增加 DRM_PANEL_SHARP_TD4722_XCMD
#   改动 3: drivers/gpu/drm/panel/Makefile 增加对应 obj
#   改动 4: 设备树 msm8996pro-xiaomi-natrium.dts 面板 compatible 改为 sharp,td4722-xcmd
# 用法: apply-sharp-panel.sh <源码目录>
# ---------------------------------------------------------------------------
set -uo pipefail
SRC="${1:?用法: apply-sharp-panel.sh <内核源码目录>}"
DRV_SRC=/mnt/c/Users/Public/natrium/stage/tools/panel-sharp-td4722-xcmd.c
[ -f "$DRV_SRC" ] || DRV_SRC=/mnt/c/Users/Public/natrium/panel-sharp-td4722-xcmd.c
[ -f "$DRV_SRC" ] || { echo "!! 找不到驱动源码 $DRV_SRC"; exit 1; }
[ -d "$SRC/drivers/gpu/drm/panel" ] || { echo "!! $SRC 不是内核源码树"; exit 1; }

cd "$SRC" || exit 1
echo "=== 源码树: $(git describe --tags 2>/dev/null || echo '?')  内核版本: $(make kernelversion 2>/dev/null || echo '?') ==="

echo
echo "=== 1) 安装面板驱动 ==="
cp -f "$DRV_SRC" drivers/gpu/drm/panel/panel-sharp-td4722-xcmd.c
ls -l drivers/gpu/drm/panel/panel-sharp-td4722-xcmd.c

echo
echo "=== 2) Kconfig 增加条目 ==="
if grep -q 'DRM_PANEL_SHARP_TD4722_XCMD' drivers/gpu/drm/panel/Kconfig; then
  echo "  已存在，跳过"
else
  python3 - <<'PY'
import re
p = "drivers/gpu/drm/panel/Kconfig"
s = open(p, encoding="utf-8").read()
entry = '''
config DRM_PANEL_SHARP_TD4722_XCMD
	tristate "Sharp TD4722 (xcmd) panel"
	depends on OF
	depends on DRM_MIPI_DSI
	depends on BACKLIGHT_CLASS_DEVICE
	help
	  Say Y here if you want to enable support for the Sharp TD4722
	  panel with xcmd init sequence (found in Xiaomi Mi 5s Plus
	  "natrium" units with a Sharp panel).
'''
anchor = 'config DRM_PANEL_JDI_FHD_R63452'
i = s.find(anchor)
if i < 0:
    # 退而求其次：插到 jdi 相关条目前，或文件末尾
    i = s.find('config DRM_PANEL_JDI_LT070ME05000')
if i < 0:
    s = s + entry
else:
    s = s[:i] + entry.lstrip("\n") + "\n" + s[i:]
open(p, "w", encoding="utf-8", newline="\n").write(s)
print("  已插入 Kconfig 条目")
PY
  grep -n -A3 'DRM_PANEL_SHARP_TD4722_XCMD' drivers/gpu/drm/panel/Kconfig | head -6
fi

echo
echo "=== 3) Makefile 增加 obj ==="
if grep -q 'panel-sharp-td4722-xcmd' drivers/gpu/drm/panel/Makefile; then
  echo "  已存在，跳过"
else
  echo 'obj-$(CONFIG_DRM_PANEL_SHARP_TD4722_XCMD) += panel-sharp-td4722-xcmd.o' >> drivers/gpu/drm/panel/Makefile
  tail -2 drivers/gpu/drm/panel/Makefile
fi

echo
echo "=== 4) 设备树把面板换成 Sharp ==="
DTS=arch/arm64/boot/dts/qcom/msm8996pro-xiaomi-natrium.dts
if grep -q 'sharp,td4722-xcmd' "$DTS"; then
  echo "  已改过，跳过"
else
  sed -i 's/compatible = "jdi,fhd-r63452";/compatible = "sharp,td4722-xcmd";/' "$DTS"
  grep -n -B2 -A6 'sharp,td4722-xcmd' "$DTS" | head -14
fi

echo
echo "=== 5) 内核配置里启用该驱动 ==="
for cfg in "config-postmarketos-qcom-msm8996.aarch64"; do
  f="/mnt/c/Users/Public/natrium/stage/$cfg"
  [ -f "$f" ] || continue
  if grep -q 'CONFIG_DRM_PANEL_SHARP_TD4722_XCMD' "$f"; then
    echo "  $cfg 已含该配置"
  else
    echo 'CONFIG_DRM_PANEL_SHARP_TD4722_XCMD=y' >> "$f"
    echo "  已追加 CONFIG_DRM_PANEL_SHARP_TD4722_XCMD=y 到 $cfg"
  fi
done

echo
echo "=== 6) 改动汇总 ==="
git status --porcelain | head -10
git diff --stat | tail -5
