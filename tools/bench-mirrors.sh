#!/usr/bin/env bash
# 用「大文件」实测真实下载带宽（决定要不要挂代理/换源）
set -uo pipefail
TMP=/tmp/spd; rm -rf "$TMP"; mkdir -p "$TMP"

# 从 APKINDEX 里找最大的包
largest() {
  local url="$1" arch="$2" repo="$3"
  curl -s --max-time 60 "$url/$repo/$arch/APKINDEX.tar.gz" -o "$TMP/idx.tar.gz" || return 1
  tar -xzOf "$TMP/idx.tar.gz" APKINDEX 2>/dev/null | python3 -c "
import sys
best=('',0)
pkg=''
for line in sys.stdin:
    line=line.rstrip('\n')
    if line.startswith('P:'): pkg=line[2:]
    elif line.startswith('S:') and pkg:
        try: s=int(line[2:])
        except: s=0
        if s>best[1]: best=(pkg,s)
print('%s %d' % best)
"
}

echo "=== 1) 找各源里最大的包 ==="
declare -A SRC
read -r P1 S1 <<< "$(largest http://mirror.nju.edu.cn/postmarketos main aarch64)"
echo "  南京大学 pmOS : $P1 ($((S1/1048576)) MB)"
read -r P2 S2 <<< "$(largest https://mirrors.tuna.tsinghua.edu.cn/alpine edge main aarch64)"
echo "  清华 Alpine   : $P2 ($((S2/1048576)) MB)"
read -r P3 S3 <<< "$(largest http://mirror.postmarketos.org/postmarketos main aarch64)"
echo "  官方 pmOS     : $P3 ($((S3/1048576)) MB)"

echo
echo "=== 2) 实测下载吞吐（只下 30MB，避免等太久）==="
bench() {
  local name="$1" url="$2"
  [ -n "$url" ] || { echo "  $name: 无可用文件"; return; }
  local out
  out=$(curl -s -o /dev/null -w '%{speed_download} %{time_total}' --max-time 45 -r 0-31457280 -L "$url" 2>/dev/null || echo "0 0")
  awk -v n="$name" -v o="$out" 'BEGIN{split(o,a," "); printf "  %-22s %7.2f MB/s  (用了 %ss)\n", n, a[1]/1048576, a[2]}'
}

[ -n "$P1" ] && bench "南京大学 pmOS" "http://mirror.nju.edu.cn/postmarketos/main/aarch64/$P1"
[ -n "$P2" ] && bench "清华 Alpine" "https://mirrors.tuna.tsinghua.edu.cn/alpine/edge/main/aarch64/$P2"
[ -n "$P3" ] && bench "官方 pmOS" "http://mirror.postmarketos.org/postmarketos/main/aarch64/$P3"
[ -n "$P3" ] && bench "官方 pmOS (IPv4)" "http://95.216.1.254/postmarketos/main/aarch64/$P3"

echo
echo "=== 3) 结论参考 ==="
echo "  >= 1.0 MB/s 正常，不需要代理"
echo "  0.3~1.0 MB/s 可接受，装完约 1 小时"
echo "  < 0.3 MB/s   建议挂代理并换国外镜像（如官方源或 ftp.halifax.rwth-aachen.de）"
