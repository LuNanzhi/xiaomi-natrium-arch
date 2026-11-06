#!/usr/bin/env bash
# 极限回收：删掉 WSL 里可以重建的内容（构建树、冗余副本、缓存、文档），保留 Ubuntu 与交叉工具链
set -uo pipefail

echo "=== 清理前 ==="
du -sh /usr /root /var 2>/dev/null
df -h / | tail -1

echo
echo "=== [1] 删除内核构建树与冗余工程副本（产物已在 Windows 工作区）==="
du -sh /root/natrium-build /root/natrium-port 2>/dev/null
rm -rf /root/natrium-build /root/natrium-port

echo
echo "=== [2] apt 缓存与索引 ==="
du -sh /var/cache/apt /var/lib/apt/lists 2>/dev/null
apt-get clean >/dev/null 2>&1
rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*.deb

echo
echo "=== [3] 日志与临时文件 ==="
rm -rf /var/log/journal/* /var/log/*.log /var/log/*.gz /var/crash/* 2>/dev/null
rm -rf /tmp/* /var/tmp/* 2>/dev/null

echo
echo "=== [4] 文档/手册/非中英文语言包（对命令行使用无影响）==="
du -sh /usr/share/doc /usr/share/man /usr/share/locale 2>/dev/null
find /usr/share/doc -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null
rm -rf /usr/share/man/* /usr/share/info/* 2>/dev/null
if [ -d /usr/share/locale ]; then
  find /usr/share/locale -mindepth 1 -maxdepth 1 -type d ! -name 'en*' ! -name 'zh*' -exec rm -rf {} + 2>/dev/null
fi

echo
echo "=== [5] 确认保留下来的编译能力 ==="
for c in aarch64-linux-gnu-gcc aarch64-linux-gnu-ld make bc bison flex dtc python3 cpio xz lz4 tar wget git; do
  printf '  %-26s %s\n' "$c" "$(command -v "$c" 2>/dev/null || echo '缺失!')"
done

echo
echo "=== 清理后 ==="
du -sh /usr /root /var 2>/dev/null
df -h / | tail -1
