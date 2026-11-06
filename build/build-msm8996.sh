#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 用 msm8996-mainline 的 v6.18.7-msm8996 树编译内核，并打包两个镜像：
#   boot-6.18.7msm8996-diag.img   带"20 秒自重启"信号，用于判定内核是否跑到用户态
#   boot-6.18.7msm8996-debug.img  正常诊断 initramfs（背光 + LED + USB 串口 shell）
# 用法: build-msm8996.sh <stage 目录(含 natrium.config 与 tools/)>
# ---------------------------------------------------------------------------
set -uo pipefail
STAGE="${1:?用法: build-msm8996.sh <stage 目录>}"
SRC=/root/linux-msm8996
OUT=/root/msm8996-build
ART=/root/msm8996-artifacts
CROSS=aarch64-linux-gnu-
JOBS="$(nproc)"
mkdir -p "$ART"

echo "### [1] 源码信息"
cd "$SRC"
sed -n '1,5p' Makefile | tr -s ' ' | grep -E 'VERSION|PATCHLEVEL|SUBLEVEL|EXTRAVERSION' || true
git log --oneline -3

echo
echo "### [2] 配置（树内 defconfig + natrium.config 片段）"
if [ ! -f "$OUT/.config" ]; then
  make ARCH=arm64 CROSS_COMPILE=$CROSS O="$OUT" defconfig >/dev/null 2>&1
  scripts/kconfig/merge_config.sh -m -O "$OUT" "$OUT/.config" "$STAGE/natrium.config" 2>&1 | grep -Ei 'value requested|not in final' || true
  make ARCH=arm64 CROSS_COMPILE=$CROSS O="$OUT" olddefconfig >/dev/null 2>&1
fi
cp "$OUT/.config" "$ART/config-msm8996-6.18.7"
echo "  关键符号:"
for s in CONFIG_DRM_MSM CONFIG_DRM_PANEL_JDI_R63452 CONFIG_DRM_FBDEV_EMULATION CONFIG_FRAMEBUFFER_CONSOLE CONFIG_RMI4_I2C CONFIG_SCSI_UFS_QCOM CONFIG_PINCTRL_MSM8996; do
  printf '    %-42s %s\n' "$s" "$(grep -E "^$s=" "$OUT/.config" | cut -d= -f2 || echo 未设置)"
done

echo
echo "### [3] 编译 Image.gz + dtbs（约 10~15 分钟）"
make -j"$JOBS" ARCH=arm64 CROSS_COMPILE=$CROSS O="$OUT" Image.gz dtbs 2>&1 | tail -20

echo
echo "### [4] 收集产物"
cp "$OUT/arch/arm64/boot/Image.gz" "$ART/" || exit 3
DTB="$OUT/arch/arm64/boot/dts/qcom/msm8996pro-xiaomi-natrium.dtb"
[ -f "$DTB" ] || { echo "!! 没有生成 natrium DTB"; exit 4; }
cp "$DTB" "$ART/"
cat "$ART/Image.gz" "$ART/msm8996pro-xiaomi-natrium.dtb" > "$ART/Image.gz-dtb"
ls -l "$ART"
# 版本串
python3 - "$ART/Image.gz" <<'PY'
import gzip, sys
raw = gzip.decompress(open(sys.argv[1], 'rb').read())
i = raw.find(b'Linux version')
print("  内核版本串:", raw[i:i+160].split(b'\x00')[0].decode('utf-8', 'replace') if i >= 0 else '未找到')
PY
# DTB 关键字段
python3 - "$ART/msm8996pro-xiaomi-natrium.dtb" <<'PY'
import struct, sys
b = open(sys.argv[1], 'rb').read()
def be32(o): return struct.unpack_from(">I", b, o)[0]
so, ss, ssz = be32(8), be32(12), be32(32)
strings = b[ss:ss+ssz]
i, depth, out = so, 0, {}
while i + 4 <= len(b):
    t = be32(i); i += 4
    if t == 1:
        e = b.index(b"\x00", i); depth += 1; i = (e + 1 + 3) & ~3
    elif t == 2: depth -= 1
    elif t == 3:
        plen = be32(i); i += 4; ns = be32(i); i += 4
        e = strings.index(b"\x00", ns); nm = strings[ns:e].decode()
        if depth <= 1: out[nm] = b[i:i+plen]
        i += (plen + 3) & ~3
    elif t == 9: break
    elif t != 4: break
print("  DTB model:", out.get("model", b"").rstrip(b"\x00").decode())
for k in ("qcom,msm-id", "qcom,board-id"):
    if k in out:
        v = out[k]
        print("  %-14s %s" % (k, [hex(be32(v, j)) for j in range(0, len(v) - 3, 4)]))
PY

echo
echo "### [5] 生成 initramfs（diag + 正常）"
mk_initramfs() {   # mk_initramfs <模式 diag|shell> <输出>
  local mode="$1" out="$2" W=/root/ir-$mode
  rm -rf "$W"; mkdir -p "$W"/{bin,proc,sys,dev,etc,tmp,lib,newroot}
  cp /usr/bin/busybox "$W/bin/busybox"; chmod +x "$W/bin/busybox"
  for l in sh ash ls cat echo mount umount dmesg sleep clear grep head tail setsid cttyhack free uname poweroff reboot date; do
    ln -sf /bin/busybox "$W/bin/$l"
  done
  ln -sf /bin/busybox "$W/init"
  {
    echo '#!/bin/busybox sh'
    echo '/bin/busybox --install -s /bin 2>/dev/null'
    echo 'export PATH=/bin:/sbin'
    echo 'mount -t proc none /proc 2>/dev/null; mount -t sysfs none /sys 2>/dev/null; mount -t devtmpfs none /dev 2>/dev/null; mount -t configfs none /sys/kernel/config 2>/dev/null'
    echo 'for f in /sys/class/backlight/*/max_brightness; do b="${f%max_brightness}brightness"; cat "$f" > "$b" 2>/dev/null; done'
    echo 'for f in /sys/class/leds/*/brightness; do echo 255 > "$f" 2>/dev/null; done'
    echo 'G=/sys/kernel/config/usb_gadget/d; mkdir -p "$G" 2>/dev/null && {'
    echo '  echo 0x18d1 > "$G/idVendor"; echo 0xd001 > "$G/idProduct"'
    echo '  mkdir -p "$G/strings/0x409" "$G/configs/c.1/strings/0x409" "$G/functions/acm.usb0"'
    echo '  echo natrium > "$G/strings/0x409/serialnumber"; echo Xiaomi > "$G/strings/0x409/manufacturer"; echo natrium-6.18.7 > "$G/strings/0x409/product"'
    echo '  echo diag > "$G/configs/c.1/strings/0x409/configuration"'
    echo '  ln -sf "$G/functions/acm.usb0" "$G/configs/c.1/" 2>/dev/null'
    echo '  U=$(ls /sys/class/udc 2>/dev/null | head -1); [ -n "$U" ] && echo "$U" > "$G/UDC" 2>/dev/null'
    echo '}'
    echo 'echo "natrium 6.18.7 init 已运行" > /dev/kmsg 2>/dev/null'
    if [ "$mode" = diag ]; then
      echo '# === 诊断信号：20 秒后强制重启 ==='
      echo 'sleep 20'
      echo 'echo b > /proc/sysrq-trigger'
      echo 'sleep 10'
      echo 'reboot -f'
    else
      echo '[ -c /dev/ttyGS0 ] && setsid sh -c "exec sh </dev/ttyGS0 >/dev/ttyGS0 2>&1" &'
      echo 'exec setsid cttyhack sh'
    fi
  } > "$W/init"
  chmod +x "$W/init"
  ( cd "$W" && find . -print0 | cpio --null -o --format=newc --quiet ) | xz -9 -C crc32 > "$out"
  echo "  $mode: $(stat -c%s "$out") bytes"
}
mk_initramfs diag  "$ART/initramfs-diag.cpio.xz"
mk_initramfs shell "$ART/initramfs-shell.cpio.xz"

echo
echo "### [6] 打包 boot.img"
CMD="console=tty0 loglevel=8 ignore_loglevel init=/init rw root=/dev/ram0"
for pair in "diag:$ART/initramfs-diag.cpio.xz" "debug:$ART/initramfs-shell.cpio.xz"; do
  tag="${pair%%:*}"; rd="${pair##*:}"
  python3 "$STAGE/tools/mk_bootimg.py" \
    --kernel "$ART/Image.gz" --dtb "$ART/msm8996pro-xiaomi-natrium.dtb" \
    --ramdisk "$rd" --cmdline "$CMD" \
    --out "$STAGE/boot-6.18.7msm8996-$tag.img" | tail -3
  python3 "$STAGE/tools/verify_bootimg.py" "$STAGE/boot-6.18.7msm8996-$tag.img" 2>&1 | tail -4
  sha256sum "$STAGE/boot-6.18.7msm8996-$tag.img"
done

echo
echo "=== 全部完成 ==="
ls -lh "$STAGE"/boot-6.18.7msm8996-*.img
