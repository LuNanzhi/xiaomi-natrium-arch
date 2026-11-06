#!/usr/bin/env bash
# 测各软件源下载速度，决定是否换国内镜像
set -uo pipefail
probe() {
  local name="$1" url="$2"
  local t
  t=$(curl -sL -o /dev/null -w '%{speed_download}' --max-time 25 "$url" 2>/dev/null || echo 0)
  # speed_download 单位 bytes/s
  awk -v n="$name" -v s="$t" 'BEGIN{ printf "  %-34s %8.2f MB/s\n", n, s/1048576 }'
}

echo "=== 下载速度实测（各取一个较大的文件，最多 25 秒）==="
probe "alpinelinux 官方" "http://dl-cdn.alpinelinux.org/alpine/edge/main/aarch64/APKINDEX.tar.gz"
probe "清华 alpine 镜像" "https://mirrors.tuna.tsinghua.edu.cn/alpine/edge/main/aarch64/APKINDEX.tar.gz"
probe "中科大 alpine 镜像" "https://mirrors.ustc.edu.cn/alpine/edge/main/aarch64/APKINDEX.tar.gz"
probe "postmarketOS 官方" "http://mirror.postmarketos.org/postmarketos/edge/aarch64/APKINDEX.tar.gz"

echo
echo "=== git 源速度（Clone GitLab 上的内核，测前 10 秒）==="
( timeout 12 git ls-remote https://gitlab.com/msm8996-mainline/linux.git refs/tags/v6.19.5-msm8996 >/dev/null 2>&1 && echo "  gitlab 可达" || echo "  gitlab 慢或不可达" )

echo
echo "=== 当前克隆进度 ==="
du -sh /root/linux-sharp/.git 2>/dev/null
ps -eo etime,cmd | grep -E 'git clone' | grep -v grep | head -2
