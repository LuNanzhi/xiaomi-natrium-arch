#!/usr/bin/env bash
# 清理 WSL 内 11GB 编译产物；先把成品 APK 与补丁保存到 C:\Users\Public\natrium\keep
set -uo pipefail
WORK=/root/.local/var/pmbootstrap
KEEP=/mnt/c/Users/Public/natrium/keep
mkdir -p "$KEEP"

echo "########## 1) 抢救成品与小文件 ##########"
# 已构建的包（内核带 Sharp 补丁 / 设备包 / 自造固件包）
for apk in "$WORK"/packages/edge/aarch64/linux-postmarketos-qcom-msm8996-*.apk \
           "$WORK"/packages/edge/aarch64/device-xiaomi-natrium-*.apk \
           "$WORK"/packages/edge/aarch64/firmware-xiaomi-natrium-*.apk; do
  [ -f "$apk" ] || continue
  cp -f "$apk" "$KEEP/" && echo "  ✅ $(basename "$apk")  ($(du -h "$apk" | cut -f1))"
done

# 内核补丁：驱动源码 + 改动说明
cp -f /root/linux-sharp/drivers/gpu/drm/panel/panel-sharp-td4722-xcmd.c "$KEEP/" 2>/dev/null && echo "  ✅ panel-sharp-td4722-xcmd.c"
cp -f /root/linux-sharp/arch/arm64/boot/dts/qcom/msm8996pro-xiaomi-natrium.dts "$KEEP/natrium-patched.dts" 2>/dev/null && echo "  ✅ natrium-patched.dts"

# pmaports 里的两处补丁
cp -f /root/pmaports/device/archived/device-xiaomi-natrium/modules-initfs "$KEEP/modules-initfs.patched" 2>/dev/null && echo "  ✅ modules-initfs.patched"
cp -f /root/pmaports/device/testing/linux-postmarketos-qcom-msm8996/config-postmarketos-qcom-msm8996.aarch64 "$KEEP/config-with-sharp-panel" 2>/dev/null && echo "  ✅ config-with-sharp-panel"
cp -f /root/pmaports/device/archived/firmware-xiaomi-natrium/firmware-xiaomi-natrium.tar.gz "$KEEP/" 2>/dev/null && echo "  ✅ firmware-xiaomi-natrium.tar.gz (37M)"

# 内核构建产物（Image.gz + dtb + config）
for d in /root/art-*; do
  [ -d "$d" ] || continue
  t="$KEEP/$(basename "$d")"
  mkdir -p "$t"
  cp -f "$d"/Image.gz "$d"/*.dtb "$d"/config-* "$t"/ 2>/dev/null
done
echo "  art-* 内核成品已复制（$(du -sh "$KEEP"/art-* 2>/dev/null | wc -l) 组）"

echo
echo "########## 2) 删除编译产物 ##########"
for d in "$WORK" /root/msm8996-build /root/linux-sharp /root/fwbuild /root/msm8996-artifacts; do
  if [ -e "$d" ]; then
    sz=$(du -sh "$d" 2>/dev/null | cut -f1)
    rm -rf "$d"
    echo "  🗑  删除 $d ($sz)"
  fi
done

echo
echo "########## 3) fstrim（让 VHD 能真正收缩）##########"
fstrim -av 2>&1 | tail -2
sync

echo
echo "########## 4) 清理后 ##########"
df -h / | tail -1
echo "--- /root 剩余 ---"
du -sh /root/* 2>/dev/null | sort -hr | head -8
echo "--- keep 目录 ---"
du -sh "$KEEP"; ls "$KEEP" | head -12
