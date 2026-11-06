#!/usr/bin/env bash
# 路线 B 完整流水线（用中国镜像加速）：
#   换镜像 → 内核配置加入 Sharp 面板驱动 → 用补丁树构建内核包 → 构建设备包
#   → 装配 Phosh 系统 → 导出线刷包 → 复制到 Windows
set -uo pipefail
PB=/root/pmbootstrap/pmbootstrap.py
WORK=/root/.local/var/pmbootstrap
KPKG=/root/pmaports/device/testing/linux-postmarketos-qcom-msm8996
NAT=/mnt/c/Users/Public/natrium

echo "########## 0) 切换软件源（南京大学 pmOS + 清华 Alpine）##########"
python3 "$PB" --as-root config mirrors.pmaports http://mirror.nju.edu.cn/postmarketos >/dev/null 2>&1
python3 "$PB" --as-root config mirrors.systemd http://mirror.nju.edu.cn/postmarketos/extra-repos/systemd >/dev/null 2>&1
python3 "$PB" --as-root config mirrors.alpine https://mirrors.tuna.tsinghua.edu.cn/alpine >/dev/null 2>&1
python3 "$PB" --as-root config mirrors.pmaports 2>&1 | tail -1
python3 "$PB" --as-root config mirrors.systemd 2>&1 | tail -1
python3 "$PB" --as-root config mirrors.alpine 2>&1 | tail -1

echo
echo "########## 1) 清理残留进程与锁 ##########"
pkill -f 'apk.static' 2>/dev/null; pkill -f 'pmbootstrap.py' 2>/dev/null; sleep 3
find "$WORK" -name 'lock' -path '*apk*' -delete 2>/dev/null
rm -f "$WORK/log.txt"
echo "  完成"

echo
echo "########## 2) 内核配置加入 Sharp 面板驱动 ##########"
CFG="$KPKG/config-postmarketos-qcom-msm8996.aarch64"
ls -l "$CFG"
if grep -q 'CONFIG_DRM_PANEL_SHARP_TD4722_XCMD' "$CFG"; then
  echo "  已存在"
else
  echo 'CONFIG_DRM_PANEL_SHARP_TD4722_XCMD=y' >> "$CFG"
  echo "  已追加"
fi
grep -c '^CONFIG_' "$CFG"
echo "  --- 更新校验和（改了 config 必须更新）---"
cd /root/pmaports && timeout 600 python3 "$PB" --as-root checksum linux-postmarketos-qcom-msm8996 2>&1 | tail -5

echo
echo "########## 3) 用 Sharp 补丁树构建内核包（最长 90 分钟）##########"
date
timeout 7200 python3 "$PB" --as-root -y build --src=/root/linux-sharp linux-postmarketos-qcom-msm8996 2>&1 | tail -35
echo "内核包构建退出码 $?"
ls -lh "$WORK"/packages/*/aarch64/linux-postmarketos-qcom-msm8996*.apk 2>/dev/null

echo
echo "########## 4) 构建设备包（归档设备必须本地构建）##########"
timeout 3600 python3 "$PB" --as-root -y build device-xiaomi-natrium 2>&1 | tail -20
echo "设备包构建退出码 $?"

echo
echo "########## 5) 装配 Phosh 完整系统（最长 150 分钟，网络较慢）##########"
date
timeout 9000 python3 "$PB" --as-root -y install --password 1234 --split 2>&1 | tail -40
echo "install 退出码 $?"
date

echo
echo "########## 6) 导出并复制到 Windows ##########"
timeout 900 python3 "$PB" --as-root export 2>&1 | tail -10
ls -lL /tmp/postmarketos-export/ 2>/dev/null
mkdir -p "$NAT/pmos"
for f in /tmp/postmarketos-export/*; do
  [ -e "$f" ] || continue
  base=$(basename "$f")
  case "$base" in
    *boot*.img|boot.img) cp -fL "$f" "$NAT/pmos/boot-sharp.img" && echo "  -> boot-sharp.img ($base)";;
    *.img) cp -fL "$f" "$NAT/pmos/$base" && echo "  -> $base";;
    *) cp -fL "$f" "$NAT/pmos/$base" 2>/dev/null && echo "  -> $base";;
  esac
done
ls -lh "$NAT/pmos/" 2>/dev/null
df -h / | tail -1
