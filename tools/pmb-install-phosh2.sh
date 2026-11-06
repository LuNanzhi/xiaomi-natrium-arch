#!/usr/bin/env bash
# 清除 apk 数据库锁（上个被杀的 install 留下的），然后重新装配带 Phosh 的完整系统
set -uo pipefail
PB=/root/pmbootstrap/pmbootstrap.py
WORK=/root/.local/var/pmbootstrap

echo "=== 1) 干掉残留的 apk / pmbootstrap 进程 ==="
ps -eo pid,etime,cmd | grep -E 'apk|pmbootstrap' | grep -v grep | head -10
pkill -f 'apk.static' 2>/dev/null && echo "  已杀 apk.static" || echo "  无 apk.static 残留"
pkill -f 'pmbootstrap.py' 2>/dev/null && echo "  已杀 pmbootstrap.py" || echo "  无 pmbootstrap.py 残留"
sleep 3

echo
echo "=== 2) 删除 apk 锁文件 ==="
find "$WORK" -name 'lock' -path '*apk*' 2>/dev/null | head -10
find "$WORK" -name 'lock' -path '*apk*' -delete 2>/dev/null && echo "  已删除锁文件"
# 也清一下 chroot 里的 db 锁
for d in "$WORK"/chroot_*/lib/apk/db/lock "$WORK"/chroot_*/var/lib/apk/lock; do
  [ -e "$d" ] && { rm -f "$d"; echo "  removed $d"; }
done

echo
echo "=== 3) 重新 install（Phosh GUI，最长 120 分钟）==="
date
timeout 7200 python3 "$PB" --as-root -y install --password 1234 --split 2>&1 | tail -50
echo "install 退出码 $?"
date
ls -lh "$WORK"/*.img 2>/dev/null
du -sh "$WORK" 2>/dev/null
df -h / | tail -1
