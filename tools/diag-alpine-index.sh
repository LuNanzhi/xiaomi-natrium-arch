#!/usr/bin/env bash
# 查 pmbootstrap 下载 Alpine 索引为何失败
set -uo pipefail
WORK=/root/.local/var/pmbootstrap

echo "=== 1) 用 Python 直接抓 Alpine 索引（模拟 pmbootstrap）==="
python3 - <<'PY'
import urllib.request, ssl, traceback
urls = [
  "https://mirrors.tuna.tsinghua.edu.cn/alpine/edge/main/x86_64/APKINDEX.tar.gz",
  "http://mirrors.tuna.tsinghua.edu.cn/alpine/edge/main/x86_64/APKINDEX.tar.gz",
  "http://mirror.nju.edu.cn/alpine/edge/main/x86_64/APKINDEX.tar.gz",
  "http://dl-cdn.alpinelinux.org/alpine/edge/main/x86_64/APKINDEX.tar.gz",
]
for u in urls:
    try:
        r = urllib.request.urlopen(u, timeout=30)
        print("  OK  %s  (%d bytes, HTTP %s)" % (u, len(r.read()), r.status))
    except Exception as e:
        print("  ERR %s  -> %s: %s" % (u, type(e).__name__, e))
PY

echo
echo "=== 2) 日志里与 alpine / 索引下载相关的内容 ==="
grep -iE 'alpine|tuna|nju|APKINDEX|download|http' "$WORK/log.txt" 2>/dev/null | tail -25

echo
echo "=== 3) 缓存目录里的索引文件与大小（对应哪个 URL 看不出来，但能看出数量）==="
ls -la "$WORK/cache_apk_x86_64/" 2>/dev/null

echo
echo "=== 4) pmbootstrap 认为的 alpine 源 ==="
python3 /root/pmbootstrap/pmbootstrap.py --as-root config mirrors.alpine 2>&1 | tail -2
grep -rn 'mirrors.alpine\|mirrors\[' /root/pmbootstrap/pmb/config/__init__.py 2>/dev/null | head -10
grep -rn 'def mirror_alpine\|mirror_alpine' /root/pmbootstrap/pmb/config/__init__.py 2>/dev/null | head -5

echo
echo "=== 5) 它在哪里拼接 alpine 仓库 URL ==="
grep -rn 'edge/main\|/main\b' /root/pmbootstrap/pmb/config/__init__.py 2>/dev/null | head -10
grep -rn 'mirrors' /root/pmbootstrap/pmb/config/__init__.py 2>/dev/null | head -12
