#!/usr/bin/env bash
# 修正 mirrors.alpine 缺少结尾斜杠的问题，然后跑完整流水线
set -uo pipefail
PB=/root/pmbootstrap/pmbootstrap.py
WORK=/root/.local/var/pmbootstrap

echo "########## 0) 修正镜像 URL（结尾加 /）##########"
python3 "$PB" --as-root config mirrors.alpine https://mirrors.tuna.tsinghua.edu.cn/alpine/ >/dev/null 2>&1
python3 "$PB" --as-root config mirrors.pmaports http://mirror.nju.edu.cn/postmarketos/ >/dev/null 2>&1
python3 "$PB" --as-root config mirrors.systemd http://mirror.nju.edu.cn/postmarketos/extra-repos/systemd/ >/dev/null 2>&1
grep -A4 '\[mirrors\]' /root/.config/pmbootstrap_v3.cfg

echo
echo "########## 1) 验证拼接后的 URL 可下载 ##########"
for u in "https://mirrors.tuna.tsinghua.edu.cn/alpine/edge/main/x86_64/apk-tools-static-3.0.8-r0.apk"; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 -L "$u"); echo "  $u -> HTTP $code"
done

echo
echo "########## 2) 清理残留 ##########"
pkill -f 'apk.static' 2>/dev/null; pkill -f 'pmbootstrap.py' 2>/dev/null; sleep 2
find "$WORK" -name 'lock' -path '*apk*' -delete 2>/dev/null
rm -f "$WORK/log.txt"

echo
echo "########## 3) 构建内核包（Sharp 补丁树，最长 90 分钟）##########"
date
timeout 7200 python3 "$PB" --as-root -y build --src=/root/linux-sharp linux-postmarketos-qcom-msm8996 2>&1 | tail -30
echo "内核包退出码 $?"
ls -lh "$WORK"/packages/*/aarch64/linux-postmarketos-qcom-msm8996*.apk 2>/dev/null

echo
echo "########## 4) 构建设备包 ##########"
timeout 3600 python3 "$PB" --as-root -y build device-xiaomi-natrium 2>&1 | tail -15
echo "设备包退出码 $?"

echo
echo "########## 5) 装配 Phosh 完整系统（最长 150 分钟）##########"
date
timeout 9000 python3 "$PB" --as-root -y install --password 1234 --split 2>&1 | tail -35
echo "install 退出码 $?"
date
ls -lh "$WORK"/*.img 2>/dev/null
du -sh "$WORK" 2>/dev/null
