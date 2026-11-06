#!/usr/bin/env bash
# 在 WSL Ubuntu 内安装 arm64 内核编译依赖。用法: bash setup-wsl.sh
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

$SUDO apt-get update
$SUDO apt-get install -y --no-install-recommends \
  build-essential bc bison flex libssl-dev libelf-dev libncurses-dev \
  gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu cpp-aarch64-linux-gnu \
  device-tree-compiler xz-utils lz4 zstd cpio kmod rsync wget curl git ca-certificates \
  python3 python3-pip busybox-static file unzip xxd dwarves lzop

echo "--- 版本确认 ---"
aarch64-linux-gnu-gcc --version | head -1
make --version | head -1
dtc --version
python3 --version
echo "OK: 依赖安装完成"
