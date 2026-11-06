#!/usr/bin/env bash
# 清理 OTA 包与解析过程解压出来的所有大文件（在 WSL 内执行）
set -uo pipefail

echo "=== 删除前占用 ==="
for d in /root/ota-work /root/vendor-tree /root/vendor-full /root/system-modules; do
  [ -e "$d" ] && du -sh "$d" 2>/dev/null
done
du -sh /mnt/c/Users/Public/wsl/ota.zip /mnt/c/Users/Public/wsl/ota-analysis 2>/dev/null
echo "WSL 根分区:"; df -h / | tail -1

echo
echo "=== 明细（ota-work 里的镜像与 dat）==="
ls -lh /root/ota-work/*.img /root/ota-work/*.dat /root/ota-work/*.br 2>/dev/null | awk '{print "  "$5"  "$9}'

echo
echo "=== 开始删除 ==="
rm -rf /root/ota-work /root/vendor-tree /root/vendor-full /root/system-modules
rm -f /mnt/c/Users/Public/wsl/ota.zip
rm -rf /mnt/c/Users/Public/wsl/ota-analysis
echo "  完成"

echo
echo "=== fstrim（回收已删除块）==="
sync
fstrim -av 2>&1 | tail -3

echo
echo "=== 确认主项目仍在（只清 OTA 相关）==="
ls -d /root/natrium-port /root/natrium-build/out-artifacts /root/natrium-build/artifacts 2>/dev/null
echo
echo "=== 删除后占用 ==="
df -h / | tail -1
