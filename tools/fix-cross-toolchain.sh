#!/usr/bin/env bash
# 修复交叉编译环境并验证能编出静态 ARM64 程序
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "=== 1) 安装 ARM64 交叉 libc 开发包 ==="
apt-get install -y --no-install-recommends libc6-dev-arm64-cross >/dev/null 2>&1
echo "  完成"

echo "=== 2) 工具链信息 ==="
aarch64-linux-gnu-gcc --version | head -1
echo "  sysroot: $(aarch64-linux-gnu-gcc -print-sysroot)"
echo "  头文件目录: $(aarch64-linux-gnu-gcc -print-file-name=include | head -1)"
ls /usr/aarch64-linux-gnu/include/stdio.h 2>/dev/null && echo "  ✅ 交叉 stdio.h 存在" || echo "  ❌ 交叉头文件仍缺失"

echo "=== 3) 试编一个静态 ARM64 程序 ==="
cat > /tmp/t.c <<'EOF'
#include <stdio.h>
int main(void) { puts("hello arm64"); return 0; }
EOF
rm -f /tmp/t
if aarch64-linux-gnu-gcc -static -O2 -o /tmp/t /tmp/t.c 2>/tmp/err; then
  echo "  编译成功:"
  file -b /tmp/t | sed 's/^/    /'
else
  echo "  编译失败:"; sed 's/^/    /' /tmp/err | head -10
fi

echo
echo "=== 4) 备选方案：下载 Alpine 的静态 aarch64 busybox ==="
cd /root
BB=/root/busybox-aarch64-static
if [ ! -x "$BB" ]; then
  VER=$(wget -qO- https://dl-cdn.alpinelinux.org/alpine/latest-stable/main/aarch64/ 2>/dev/null | grep -o 'busybox-static-[0-9][^"]*\.apk' | head -1)
  echo "  包名: ${VER:-未找到}"
  if [ -n "${VER:-}" ]; then
    wget -qO /root/bb.apk "https://dl-cdn.alpinelinux.org/alpine/latest-stable/main/aarch64/$VER" && echo "  已下载 $(stat -c%s /root/bb.apk) bytes"
    python3 - <<'PY'
import gzip, io, tarfile, os, sys
raw = gzip.decompress(open('/root/bb.apk','rb').read())
pos = 0
while pos < len(raw) - 1024:
    try: tf = tarfile.open(fileobj=io.BytesIO(raw[pos:]), mode='r:')
    except Exception: break
    if not tf.getnames(): break
    for m in tf.getmembers():
        if m.isfile() and 'busybox' in os.path.basename(m.name):
            data = tf.extractfile(m).read()
            open('/root/busybox-aarch64-static','wb').write(data)
            os.chmod('/root/busybox-aarch64-static', 0o755)
            print('  抽出 %s (%d bytes)' % (m.name, len(data)))
    pos += tf.offset
PY
  fi
fi
if [ -x "$BB" ]; then
  file -b "$BB" | sed 's/^/  /'
  case "$(file -b "$BB")" in
    *"ARM aarch64"*"statically linked"*) echo "  ✅ 可用的静态 aarch64 busybox" ;;
    *) echo "  ⚠ 架构或链接方式不符" ;;
  esac
else
  echo "  (未获得备用 busybox)"
fi
