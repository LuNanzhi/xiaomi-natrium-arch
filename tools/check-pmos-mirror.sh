#!/usr/bin/env bash
# 确认 pmOS 软件源到底通不通（以及 chroot 里实际用的 URL）
set -uo pipefail

echo "=== 1) chroot 里 apk 的仓库列表（pmbootstrap 实际使用的 URL）==="
for f in /root/.local/var/pmbootstrap/chroot_native/etc/apk/repositories \
         /root/.local/var/pmbootstrap/chroot_rootfs_xiaomi-natrium/etc/apk/repositories; do
  echo "--- $f"
  cat "$f" 2>/dev/null || echo "  (不存在)"
done

echo
echo "=== 2) HTTP 状态与速度逐个测 ==="
for u in \
  "http://mirror.postmarketos.org/postmarketos/master/aarch64/APKINDEX.tar.gz" \
  "https://mirror.postmarketos.org/postmarketos/master/aarch64/APKINDEX.tar.gz" \
  "http://mirror.postmarketos.org/postmarketos/systemd-edge/aarch64/APKINDEX.tar.gz" \
  "https://mirrors.sjtug.sjtu.edu.cn/postmarketos/master/aarch64/APKINDEX.tar.gz" \
  "https://mirror.funami.tech/postmarketos/master/aarch64/APKINDEX.tar.gz" \
  "https://mirrors.tuna.tsinghua.edu.cn/postmarketos/master/aarch64/APKINDEX.tar.gz" ; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 -L "$u" 2>/dev/null || echo "ERR")
  spd=$(curl -s -o /dev/null -w '%{speed_download}' --max-time 20 -L "$u" 2>/dev/null || echo 0)
  awk -v u="$u" -v c="$code" -v s="$spd" 'BEGIN{ printf "  %-78s HTTP %-5s %6.2f MB/s\n", u, c, s/1048576 }'
done

echo
echo "=== 3) DNS 解析 ==="
getent hosts mirror.postmarketos.org || echo "  解析失败"
getent hosts dl-cdn.alpinelinux.org | head -2

echo
echo "=== 4) pmbootstrap 配置里的源 ==="
grep -E 'mirror' /root/.config/pmbootstrap_v3.cfg
