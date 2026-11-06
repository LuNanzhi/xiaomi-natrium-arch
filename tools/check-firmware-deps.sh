#!/usr/bin/env bash
# 核查 extra_packages 空项 与 固件包/设备包在二进制仓库里的可用性
set -uo pipefail

echo "=== 1) 配置里的 extra_packages ==="
grep -n 'extra_packages' /root/.config/pmbootstrap_v3.cfg
python3 /mnt/c/Users/Public/natrium/check_cfg.py

echo
echo "=== 2) pmOS 二进制仓库里是否有这些包 ==="
curl -s --max-time 90 http://mirror.nju.edu.cn/postmarketos/main/aarch64/APKINDEX.tar.gz -o /tmp/idx.tgz
for p in firmware-xiaomi-natrium device-xiaomi-natrium linux-postmarketos-qcom-msm8996 postmarketos-base-systemd postmarketos-ui-phosh; do
  n=$(tar -xzO -f /tmp/idx.tgz APKINDEX 2>/dev/null | grep -c "^P:$p$")
  echo "  $p -> 命中 $n"
done

echo
echo "=== 3) 固件源码仓库状态 ==="
curl -s -o /dev/null -w '  项目页 HTTP %{http_code}\n' --max-time 30 https://gitlab.com/AlecJY/firmware-xiaomi-natrium
curl -s -o /dev/null -w '  API    HTTP %{http_code}\n' --max-time 30 https://gitlab.com/api/v4/projects/AlecJY%2Ffirmware-xiaomi-natrium

echo
echo "=== 4) 设备包对固件的依赖声明 ==="
grep -n -A8 'depends' /root/pmaports/device/archived/device-xiaomi-natrium/APKBUILD | head -20
echo "  --- 固件包内容清单 ---"
head -20 /root/pmaports/device/archived/firmware-xiaomi-natrium/firmware.files 2>/dev/null
echo "  --- 固件包 APKBUILD 源 ---"
grep -nE 'source=|sha512|url=|pkgver' /root/pmaports/device/archived/firmware-xiaomi-natrium/APKBUILD | head -10
