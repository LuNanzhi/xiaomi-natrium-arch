#!/usr/bin/env bash
# 测中国/亚洲 pmOS 镜像速度，挑最快的
set -uo pipefail
echo "=== pmOS 包索引测速（每种源最多 20 秒）==="
for m in \
  "http://mirror.nju.edu.cn/postmarketos" \
  "https://mirror.nju.edu.cn/postmarketos" \
  "https://mirrors.ustc.edu.cn/postmarketos" \
  "https://mirrors.nura.eco" \
  "https://mirror-sg.mainlining.org/postmarketos" \
  "https://ftp.halifax.rwth-aachen.de/postmarketos" \
  "https://mirror.postmarketos.org/postmarketos" ; do
  u="$m/main/aarch64/APKINDEX.tar.gz"
  out=$(curl -s -o /dev/null -w '%{http_code} %{speed_download}' --max-time 20 -L "$u" 2>/dev/null || echo "ERR 0")
  awk -v u="$m" -v o="$out" 'BEGIN{n=split(o,a," "); printf "  %-52s HTTP %-5s %7.2f MB/s\n", u, a[1], a[2]/1048576}'
done

echo
echo "=== systemd 附加仓库是否也被镜像（extra-repos/systemd/main）==="
for m in "http://mirror.nju.edu.cn/postmarketos" "https://mirrors.ustc.edu.cn/postmarketos" "https://mirrors.nura.eco"; do
  u="$m/extra-repos/systemd/main/aarch64/APKINDEX.tar.gz"
  out=$(curl -s -o /dev/null -w '%{http_code} %{speed_download}' --max-time 20 -L "$u" 2>/dev/null || echo "ERR 0")
  awk -v u="$m" -v o="$out" 'BEGIN{n=split(o,a," "); printf "  %-52s HTTP %-5s %7.2f MB/s\n", u, a[1], a[2]/1048576}'
done

echo
echo "=== 顺带测 Alpine 中国镜像（base 系统包）==="
for m in "https://mirror.nju.edu.cn/alpine" "https://mirrors.ustc.edu.cn/alpine" "https://mirrors.tuna.tsinghua.edu.cn/alpine"; do
  u="$m/edge/main/aarch64/APKINDEX.tar.gz"
  out=$(curl -s -o /dev/null -w '%{http_code} %{speed_download}' --max-time 15 -L "$u" 2>/dev/null || echo "ERR 0")
  awk -v u="$m" -v o="$out" 'BEGIN{n=split(o,a," "); printf "  %-52s HTTP %-5s %7.2f MB/s\n", u, a[1], a[2]/1048576}'
done

echo
echo "=== 真正的大文件测速（拿一个较大的 apk：phosh 相关基础包）==="
u="http://mirror.nju.edu.cn/postmarketos/main/aarch64/"
curl -s --max-time 20 -L "$u" 2>/dev/null | grep -oE 'href="[^"]*\.apk"' | head -5
