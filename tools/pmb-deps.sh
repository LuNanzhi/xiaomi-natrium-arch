#!/usr/bin/env bash
# 安装 pmbootstrap 需要的系统工具，然后验证配置
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "=== 安装依赖工具 ==="
apt-get install -y --no-install-recommends \
  kpartx parted e2fsprogs dosfstools mtools xz-utils bzip2 unzip zip openssl bc file \
  git python3 curl wget util-linux coreutils >/dev/null 2>&1
for p in kpartx parted mkfs.ext4 mkfs.vfat mcopy xz openssl bc file; do
  printf '  %-12s %s\n' "$p" "$(command -v "$p" || echo '缺失')"
done

PB=/root/pmbootstrap/pmbootstrap.py
echo
echo "=== pmbootstrap status ==="
python3 "$PB" --as-root status 2>&1 | sed -n '1,45p'

echo
echo "=== deviceinfo_parse ==="
python3 "$PB" --as-root deviceinfo_parse 2>&1 | sed -n '1,40p'
