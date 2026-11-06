#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 构建「诊断镜像」：initramfs 里做一个主机可见的信号（20 秒后强制重启）。
#   手机自己重启     -> 内核跑到了用户态 init（说明内核 OK，只是显示/USB 没通）
#   完全没动静       -> 内核在 init 之前就挂了
# 用法(在 WSL 内): bash build-diag-image.sh <stage 目录(纯 ASCII)>
# ---------------------------------------------------------------------------
set -uo pipefail
STAGE="${1:?用法: build-diag-image.sh <stage 目录>}"
W=/root/diag-build

rm -rf "$W"; mkdir -p "$W/root"/{bin,proc,sys,dev,etc,tmp,lib,newroot}

echo "### [1] 组装 initramfs"
BB="$(command -v busybox || true)"
[ -n "$BB" ] || { echo "!! 缺 busybox（apt install busybox-static）"; exit 1; }
echo "  busybox: $BB"
cp "$BB" "$W/root/bin/busybox"; chmod +x "$W/root/bin/busybox"
for l in sh ash ls cat echo mount umount dmesg sleep clear grep head tail setsid cttyhack free uname poweroff reboot date; do
  ln -sf /bin/busybox "$W/root/bin/$l"
done
ln -sf /bin/busybox "$W/root/init"

cat > "$W/root/init" <<'INIT'
#!/bin/busybox sh
/bin/busybox --install -s /bin 2>/dev/null
export PATH=/bin:/sbin
mount -t proc none /proc 2>/dev/null
mount -t sysfs none /sys 2>/dev/null
mount -t devtmpfs none /dev 2>/dev/null
mount -t configfs none /sys/kernel/config 2>/dev/null

# --- 可见信号 1：背光拉满 ---
for f in /sys/class/backlight/*/max_brightness; do
  [ -e "$f" ] || continue
  b="${f%max_brightness}brightness"
  cat "$f" > "$b" 2>/dev/null
done
# --- 可见信号 2：所有 LED 点亮 ---
for f in /sys/class/leds/*/brightness; do
  [ -e "$f" ] && echo 255 > "$f" 2>/dev/null
done
# --- 可见信号 3：USB ACM 串口（电脑上会多一个 COM 口） ---
G=/sys/kernel/config/usb_gadget/diag
if mkdir -p "$G" 2>/dev/null; then
  echo 0x18d1 > "$G/idVendor" 2>/dev/null
  echo 0xd001 > "$G/idProduct" 2>/dev/null
  mkdir -p "$G/strings/0x409" 2>/dev/null
  echo "natrium-diag" > "$G/strings/0x409/serialnumber" 2>/dev/null
  echo "Xiaomi" > "$G/strings/0x409/manufacturer" 2>/dev/null
  echo "natrium-diag" > "$G/strings/0x409/product" 2>/dev/null
  mkdir -p "$G/configs/c.1/strings/0x409" 2>/dev/null
  echo "diag" > "$G/configs/c.1/strings/0x409/configuration" 2>/dev/null
  mkdir -p "$G/functions/acm.usb0" 2>/dev/null
  ln -sf "$G/functions/acm.usb0" "$G/configs/c.1/" 2>/dev/null
  U="$(ls /sys/class/udc 2>/dev/null | head -1)"
  [ -n "$U" ] && echo "$U" > "$G/UDC" 2>/dev/null
  echo "  UDC=$U" > /dev/kmsg 2>/dev/null
fi

echo "natrium-diag: init 已运行，内核 $(uname -r)" > /dev/kmsg 2>/dev/null

# --- 决定性信号：20 秒后强制重启 ---
sleep 20
echo b > /proc/sysrq-trigger
sleep 10
reboot -f
INIT
chmod +x "$W/root/init"

( cd "$W/root" && find . -print0 | cpio --null -o --format=newc --quiet ) | xz -9 -C crc32 > "$W/initramfs-diag.cpio.xz"
echo "  initramfs: $(stat -c%s "$W/initramfs-diag.cpio.xz") bytes"

echo
echo "### [2] 打包诊断 boot.img（复用已编译好的内核与 DTB）"
python3 "$STAGE/tools/mk_bootimg.py" \
  --kernel  "$STAGE/Image.gz" \
  --dtb     "$STAGE/msm8996pro-xiaomi-natrium.dtb" \
  --ramdisk "$W/initramfs-diag.cpio.xz" \
  --cmdline "console=tty0 loglevel=8 ignore_loglevel init=/init rw root=/dev/ram0" \
  --out     "$STAGE/boot-6.18.55-natrium-diag.img"

echo
echo "### [3] 校验"
sha256sum "$STAGE/boot-6.18.55-natrium-diag.img"
python3 "$STAGE/tools/verify_bootimg.py" "$STAGE/boot-6.18.55-natrium-diag.img" 2>&1 | tail -6
echo "  含 20 秒重启逻辑: $(grep -c 'sysrq-trigger' "$W/root/init") 处"
