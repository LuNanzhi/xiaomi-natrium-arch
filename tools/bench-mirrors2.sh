#!/usr/bin/env bash
# 用最大包的 30MB 实测真实带宽（curl 实现，避免 Python 证书问题）
set -uo pipefail
PICK=/mnt/c/Users/Public/natrium/pick_largest_pkg.py
TMP=/tmp/bm; mkdir -p "$TMP"

test_mirror() {
  local name="$1" base="$2"
  curl -s --max-time 90 "$base/APKINDEX.tar.gz" -o "$TMP/idx.tgz" || { echo "  $name: 索引下载失败"; return; }
  local sz; sz=$(stat -c%s "$TMP/idx.tgz" 2>/dev/null || echo 0)
  [ "$sz" -gt 1000 ] || { echo "  $name: 索引太小($sz)"; return; }
  local pick; pick=$(tar -xzOf "$TMP/idx.tgz" APKINDEX 2>/dev/null | python3 "$PICK")
  [ -n "$pick" ] || { echo "  $name: 解析失败"; return; }
  set -- $pick
  local file="$1" size="$2"
  local out; out=$(curl -s -o /dev/null -w '%{speed_download} %{size_download} %{time_total}' --max-time 50 -r 0-31457279 -L "$base/$file" 2>/dev/null || echo "0 0 0")
  awk -v n="$name" -v f="$file" -v s="$size" -v o="$out" 'BEGIN{split(o,a," "); printf "  %-14s %-34s %7.2f MB/s  (%d MB 包, 取了 %.1f MB)\n", n, f, a[1]/1048576, s/1048576, a[2]/1048576}'
}

echo "=== 30MB 实测吞吐（这才是真实带宽）==="
test_mirror "南京大学 pmOS" "http://mirror.nju.edu.cn/postmarketos/main/aarch64"
test_mirror "清华 Alpine" "https://mirrors.tuna.tsinghua.edu.cn/alpine/edge/main/aarch64"
test_mirror "官方 pmOS" "http://mirror.postmarketos.org/postmarketos/main/aarch64"
test_mirror "哈雷 RWTH" "https://ftp.halifax.rwth-aachen.de/postmarketos/main/aarch64"

echo
echo "=== 当前内核编译进度（顺便看看，不影响）==="
tail -2 /root/.local/var/pmbootstrap/log.txt 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g'
ls -d /root/.local/var/pmbootstrap/packages/*/aarch64/linux-postmarketos-qcom-msm8996*.apk 2>/dev/null || echo "  内核包尚未产出"
