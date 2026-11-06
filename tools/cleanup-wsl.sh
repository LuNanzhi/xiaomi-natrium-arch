#!/usr/bin/env bash
# 清理 WSL 内的编译产物：保留内核成品（Image.gz + dtb）与工具链
set -uo pipefail

echo "=== 0) 清理前 ==="
df -h / | tail -1

echo
echo "=== 1) 先把 6.18.55 的内核成品抢救出来（之后要删它的树）==="
if [ -d /root/natrium-build/out-artifacts ]; then
  mkdir -p /root/art-61855
  cp -f /root/natrium-build/out-artifacts/Image.gz /root/art-61855/ 2>/dev/null
  cp -f /root/natrium-build/out-artifacts/msm8996pro-xiaomi-natrium.dtb /root/art-61855/ 2>/dev/null
  ls -l /root/art-61855/ 2>/dev/null || echo "  (没有可抢救的文件)"
else
  echo "  (out-artifacts 不存在)"
fi

echo
echo "=== 2) 删除内核源码树与编译目录 ==="
for d in /root/linux-msm8996 /root/linux-6195 /root/linux-6.17.8 /root/linux-6.12.10 \
         /root/build-6195 /root/build-6187 /root/build-6.17.8 /root/build-6.12.10 \
         /root/natrium-build; do
  if [ -e "$d" ]; then
    sz=$(du -sh "$d" 2>/dev/null | cut -f1)
    rm -rf "$d"
    echo "  deleted $d ($sz)"
  fi
done

echo
echo "=== 3) 删除其它中间产物与缓存 ==="
for d in /root/bb-ir /root/static-ir /root/static-ir2 /root/pmb-venv /root/bb.apk /root/linux-6.18.55; do
  [ -e "$d" ] && { rm -rf "$d"; echo "  deleted $d"; }
done
rm -rf /var/cache/apt/archives/*.deb 2>/dev/null && echo "  cleared apt cache"
rm -rf /tmp/ir* /tmp/ircheck /tmp/ir.cpio /tmp/t /tmp/t.c /tmp/err /tmp/linux-* 2>/dev/null
apt-get clean >/dev/null 2>&1

echo
echo "=== 4) 清理后 ==="
df -h / | tail -1
echo "--- 保留的关键内容 ---"
du -sh /root/art-* /root/busybox-aarch64-static /root/static-ir* 2>/dev/null | sort -hr
ls /root/art-6187 /root/art-6195 2>/dev/null
echo "--- 交叉工具链 ---"
aarch64-linux-gnu-gcc --version | head -1
