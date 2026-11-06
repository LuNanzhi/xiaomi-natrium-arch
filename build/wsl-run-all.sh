#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 在已导入的 WSL Ubuntu 内执行：同步工程 → 装依赖 → 编译 6.18.55 → initramfs → 打包 boot.img
# 幂等：各阶段失败即停止并保留日志；重跑会从失败处继续（源码与配置会复用）。
# ---------------------------------------------------------------------------
set -uo pipefail
# 用法: wsl-run-all.sh [工程目录的 WSL 路径]   —— 默认用 Windows 工作区（含中文路径）
WS="${1:-/mnt/c/Users/江月白/Documents/deepseek-harness/default-workspace/natrium-port}"
LOG="/root/natrium-port-log.txt"
mkdir -p "$(dirname "$LOG")"
exec > >(tee -a "$LOG") 2>&1

echo "################ $(date '+%F %T') 开始 ################"

echo "### [0] 同步工程到 WSL (/root/natrium-port)"
mkdir -p /root/natrium-port
cp -r "$WS/." /root/natrium-port/
# 清理可能的 CRLF，并保证可执行
find /root/natrium-port -type f \( -name '*.sh' -o -name '*.py' -o -name '*.config' \) -print0 \
  | xargs -0 sed -i 's/\r$//' 2>/dev/null || true
chmod +x /root/natrium-port/build/*.sh /root/natrium-port/tools/*.sh 2>/dev/null || true
ls -R /root/natrium-port | head -40

echo "### [1] 系统信息"
. /etc/os-release; echo "$PRETTY_NAME  arch=$(uname -m)  cpu=$(nproc)  mem=$(free -g | awk '/Mem:/{print $2}')G"
df -h / | tail -1

# 确保 universe 源可用
if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
  sed -i 's/^Components:.*/Components: main restricted universe multiverse/' /etc/apt/sources.list.d/ubuntu.sources
fi
if [ -f /etc/apt/sources.list ]; then
  grep -q universe /etc/apt/sources.list || sed -i 's/ main$/ main universe/' /etc/apt/sources.list
fi

echo "### [2] 安装编译依赖"
if ! bash /root/natrium-port/build/setup-wsl.sh; then
  echo "!!!! [2] 依赖安装失败 (exit $?)"; exit 11
fi

echo "### [3] 编译内核 6.18.55 (KEEP_OUT=${KEEP_OUT:-0})"
if ! KEEP_OUT="${KEEP_OUT:-0}" bash /root/natrium-port/build/build-kernel.sh 6.18.55 /root/natrium-build; then
  echo "!!!! [3] 内核编译失败，回传配置与日志以便排查"
  mkdir -p "$WS/out"
  cp -v /root/natrium-build/out/.config "$WS/out/config-failed.txt" 2>/dev/null || true
  cp -v /root/natrium-build/out-artifacts/build.log "$WS/out/build.log" 2>/dev/null || true
  exit 12
fi

echo "### [4] 生成 bring-up initramfs"
if ! bash /root/natrium-port/build/make-initramfs.sh /root/natrium-build/initramfs-root \
        /root/natrium-build/artifacts/initramfs-debug.cpio.xz; then
  echo "!!!! [4] initramfs 生成失败"; exit 13
fi

echo "### [5] 打包 boot.img"
ART=/root/natrium-build/out-artifacts
if ! python3 /root/natrium-port/tools/mk_bootimg.py \
      --kernel  "$ART/Image.gz" \
      --dtb     "$ART/msm8996pro-xiaomi-natrium.dtb" \
      --ramdisk /root/natrium-build/artifacts/initramfs-debug.cpio.xz \
      --cmdline "console=tty0 console=ttyMSM0,115200n8 loglevel=8 init=/init rw root=/dev/ram0" \
      --out     /root/natrium-build/artifacts/boot-6.18.55-natrium-debug.img; then
  echo "!!!! [5] 打包失败"; exit 14
fi

echo "### [6] 回传产物到 Windows 工作区"
mkdir -p "$WS/out"
cp -v /root/natrium-build/artifacts/boot-6.18.55-natrium-debug.img "$WS/out/" 2>/dev/null
cp -v "$ART/Image.gz" "$ART/msm8996pro-xiaomi-natrium.dtb" "$ART/Image.gz-dtb" "$WS/out/" 2>/dev/null
cp -v "$ART/config-6.18-natrium" "$WS/out/config-6.18-natrium" 2>/dev/null
cp -v /root/natrium-build/artifacts/initramfs-debug.cpio.xz "$WS/out/" 2>/dev/null
cp -v "$ART/modules.tar.gz" "$WS/out/" 2>/dev/null
cp -v "$ART/build.log" "$WS/out/build.log" 2>/dev/null
ls -lh "$WS/out" || true

echo "### [7] 产物校验"
python3 /root/natrium-port/tools/bootimg_info.py info /root/natrium-build/artifacts/boot-6.18.55-natrium-debug.img || true
sha256sum /root/natrium-build/artifacts/boot-6.18.55-natrium-debug.img || true
# 确认新内核里真的带 6.18.55 版本串
python3 - <<'PY' || true
import gzip
d=open('/root/natrium-build/out-artifacts/Image.gz','rb').read()
raw=gzip.decompress(d)
i=raw.find(b'Linux version')
print('内核版本串:', raw[i:i+160].split(b'\x00')[0].decode('utf-8','replace') if i>=0 else '未找到')
PY

echo "################ $(date '+%F %T') 全部完成 ################"
