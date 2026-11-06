#!/usr/bin/env bash
# 找可用的 pmOS 镜像源（IPv4 / 其它镜像站）
set -uo pipefail

echo "=== 1) mirror.postmarketos.org 的 IPv4 记录 ==="
getent ahostsv4 mirror.postmarketos.org | head -3 || echo "  没有 IPv4 记录"
echo "  --- 强制 IPv4 测速 ---"
for u in "http://mirror.postmarketos.org/postmarketos/main/aarch64/APKINDEX.tar.gz" \
         "https://mirror.postmarketos.org/postmarketos/main/aarch64/APKINDEX.tar.gz"; do
  out=$(curl -4 -s -o /dev/null -w '%{http_code} %{speed_download}' --max-time 25 -L "$u" 2>/dev/null || echo "ERR 0")
  echo "  $u -> $out"
done

echo
echo "=== 2) pmOS 官方镜像列表 ==="
curl -s --max-time 25 -L https://postmarketos.org/mirrors/ 2>/dev/null | grep -oE 'https?://[a-zA-Z0-9._/-]*postmarketos[a-zA-Z0-9._/-]*' | sort -u | head -20 || echo "  抓取失败"
echo "  --- 试 wiki ---"
curl -s --max-time 25 -L "https://wiki.nura.eco/index.php?title=Mirrors&action=raw" 2>/dev/null | head -30 || echo "  抓取失败"

echo
echo "=== 3) 逐个测已知镜像 ==="
for u in \
  "https://mirror.postmarketos.org/postmarketos/main/aarch64/APKINDEX.tar.gz" \
  "http://mirror.postmarketos.org/postmarketos/main/aarch64/APKINDEX.tar.gz" \
  "https://mirrors.dotsrc.org/postmarketos/main/aarch64/APKINDEX.tar.gz" \
  "https://mirror.kumi.systems/postmarketos/main/aarch64/APKINDEX.tar.gz" \
  "https://ftp.halifax.rwth-aachen.de/postmarketos/main/aarch64/APKINDEX.tar.gz" \
  "https://mirrors.xtom.com.hk/postmarketos/main/aarch64/APKINDEX.tar.gz" \
  "https://mirrors.xtom.de/postmarketos/main/aarch64/APKINDEX.tar.gz" \
  "https://mirror.leitecastro.com/postmarketos/main/aarch64/APKINDEX.tar.gz" ; do
  out=$(curl -s -o /dev/null -w '%{http_code} %{speed_download}' --max-time 15 -L "$u" 2>/dev/null || echo "ERR 0")
  echo "  $out  $u"
done
