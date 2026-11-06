#!/usr/bin/env bash
# 诊断 pmbootstrap 为什么解析不到 apk-tools-static
set -uo pipefail
WORK=/root/.local/var/pmbootstrap
PB=/root/pmbootstrap/pmbootstrap.py

echo "=== 1) 缓存里的 APKINDEX 是否包含 apk-tools-static ==="
for arch in x86_64 aarch64; do
  f="$WORK/cache_apk_$arch/APKINDEX.tar.gz"
  if [ -f "$f" ]; then
    n=$(tar -xzOf "$f" APKINDEX 2>/dev/null | grep -c '^P:apk-tools-static')
    echo "  $arch: $(stat -c%s "$f") bytes, 含 apk-tools-static 条目 $n 个"
  else
    echo "  $arch: 索引不存在"
  fi
done

echo
echo "=== 2) 索引里都下载了哪些仓库（看 URL 与文件）==="
ls -la "$WORK"/cache_apk_x86_64/ 2>/dev/null | head -10

echo
echo "=== 3) pmbootstrap 解析用的索引列表（日志里的 APKINDEX URL）==="
grep -oE 'https?://[^ "]*APKINDEX[^ "]*' "$WORK/log.txt" 2>/dev/null | sort -u | head -10

echo
echo "=== 4) 原生 chroot 的仓库列表 ==="
cat "$WORK/chroot_native/etc/apk/repositories" 2>/dev/null

echo
echo "=== 5) 手工从索引里找 apk-tools-static（模拟 pmbootstrap 的解析）==="
f="$WORK/cache_apk_x86_64/APKINDEX.tar.gz"
if [ -f "$f" ]; then
  tar -xzOf "$f" APKINDEX 2>/dev/null | awk '/^P:apk-tools-static$/{found=1; print "  找到:", $0} /^V:/{if(found){print "  版本:", $0; found=0}}' | head -6
  echo "  --- 索引里的包总数 ---"
  tar -xzOf "$f" APKINDEX 2>/dev/null | grep -c '^P:'
fi

echo
echo "=== 6) pmbootstrap 的 related 源码（哪里抛这个错）==="
sed -n '255,280p' /root/pmbootstrap/pmb/parse/apkindex.py
echo "  --- 它用哪些 index 文件 ---"
grep -rn 'def providers' -A12 /root/pmbootstrap/pmb/parse/apkindex.py | head -20
