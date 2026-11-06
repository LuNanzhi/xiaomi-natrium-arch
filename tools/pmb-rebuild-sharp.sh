#!/usr/bin/env bash
# 修好 Sharp 驱动的 remove() 签名后，重新编译内核包并继续流水线
set -uo pipefail
PB=/root/pmbootstrap/pmbootstrap.py
WORK=/root/.local/var/pmbootstrap
NAT=/mnt/c/Users/Public/natrium
TREE=/root/linux-sharp
DRV="$NAT/stage/tools/panel-sharp-td4722-xcmd.c"

echo "########## 0) 更新驱动源码（remove 改为 void）##########"
[ -f "$DRV" ] || DRV="$NAT/panel-sharp-td4722-xcmd.c"
grep -n 'sharp_td4722_xcmd_remove' "$DRV" | head -3
cp -f "$DRV" "$TREE/drivers/gpu/drm/panel/panel-sharp-td4722-xcmd.c"
echo "  已更新到 $TREE"
grep -n -A3 'static void sharp_td4722_xcmd_remove' "$TREE/drivers/gpu/drm/panel/panel-sharp-td4722-xcmd.c"

echo
echo "########## 1) 清理上次失败的构建残留 ##########"
pkill -f 'abuild' 2>/dev/null; pkill -f 'apk.static' 2>/dev/null; pkill -f 'pmbootstrap.py' 2>/dev/null; sleep 3
find "$WORK" -name 'lock' -path '*apk*' -delete 2>/dev/null
rm -f "$WORK/log.txt"
# 清掉上次的编译目录，避免半成品
rm -rf "$WORK/chroot_native/home/pmos/build" 2>/dev/null
echo "  完成"

echo
echo "########## 2) 重新编译内核包（最长 90 分钟）##########"
date
timeout 7200 python3 "$PB" --as-root -y build --src="$TREE" linux-postmarketos-qcom-msm8996 2>&1 | tail -30
echo "内核包退出码 $?"
ls -lh "$WORK"/packages/*/aarch64/linux-postmarketos-qcom-msm8996*.apk 2>/dev/null
echo "--- 日志里 Sharp 驱动/错误 ---"
grep -iE 'panel-sharp-td4722|error:' "$WORK/log.txt" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | tail -8

echo
echo "########## 3) 构建设备包 ##########"
timeout 3600 python3 "$PB" --as-root -y build device-xiaomi-natrium 2>&1 | tail -12
echo "设备包退出码 $?"

echo
echo "########## 4) 装配 Phosh 完整系统（最长 120 分钟）##########"
date
timeout 7200 python3 "$PB" --as-root -y install --password 1234 --split 2>&1 | tail -35
echo "install 退出码 $?"
date
ls -lh "$WORK"/*.img 2>/dev/null

echo
echo "########## 5) 导出到 Windows ##########"
timeout 900 python3 "$PB" --as-root export 2>&1 | tail -8
ls -lL /tmp/postmarketos-export/ 2>/dev/null
mkdir -p "$NAT/pmos"
for f in /tmp/postmarketos-export/*; do
  [ -e "$f" ] || continue
  base=$(basename "$f")
  case "$base" in
    boot*.img) cp -fL "$f" "$NAT/pmos/boot-sharp.img" && echo "  -> boot-sharp.img ($base)";;
    *) cp -fL "$f" "$NAT/pmos/$base" 2>/dev/null && echo "  -> $base";;
  esac
done
ls -lh "$NAT/pmos/" 2>/dev/null
du -sh "$WORK" 2>/dev/null
df -h / | tail -1
