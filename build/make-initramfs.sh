#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 生成 bring-up 用最小 initramfs（有屏幕 log + USB 串口 shell，可无串口硬件调试）
#
# 用法: bash make-initramfs.sh [输出目录] [输出文件.cpio.xz]
# 依赖: busybox-static, xz
# ---------------------------------------------------------------------------
set -euo pipefail
DIR="${1:-$HOME/natrium-build/initramfs-root}"
OUT="${2:-$HOME/natrium-build/artifacts/initramfs-debug.cpio.xz}"

rm -rf "$DIR"
mkdir -p "$DIR"/{bin,sbin,proc,sys,dev,etc,tmp,lib,newroot}
mkdir -p "$(dirname "$OUT")"

BUSYBOX="$(command -v busybox || true)"
[ -n "$BUSYBOX" ] || { echo "!! 需要 busybox-static: apt install busybox-static"; exit 1; }
cp "$BUSYBOX" "$DIR/bin/busybox"
chmod +x "$DIR/bin/busybox"
for l in sh ash ls cat echo mount umount uname dmesg sleep mkdir mknod ln clear head tail grep vi \
         ifconfig ip udhcpc telnetd httpd setsid cttyhack poweroff reboot free df cut sed awk ps top; do
  ln -sf /bin/busybox "$DIR/bin/$l"
done
ln -sf /bin/busybox "$DIR/init"

cat > "$DIR/init" <<'EOF'
#!/bin/busybox sh
/bin/busybox --install -s /bin 2>/dev/null
export PATH=/bin:/sbin
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev 2>/dev/null || mdev -s
mount -t configfs none /sys/kernel/config 2>/dev/null

echo "=== natrium mainline 6.18 bring-up initramfs ==="
uname -a
cat /proc/device-tree/model 2>/dev/null; echo
echo "-- 显示/背光 --"
for f in /sys/class/drm/*/status; do [ -e "$f" ] && echo "  $f: $(cat "$f")"; done
for m in /sys/class/backlight/*/max_brightness; do
  [ -e "$m" ] || continue
  b="${m%max_brightness}brightness"
  echo "  背光 $(dirname "$m"): max=$(cat "$m") -> 拉满"
  cat "$m" > "$b" 2>/dev/null || echo 255 > "$b" 2>/dev/null || true
done
echo "-- 存储 --"
for d in /sys/class/block/*; do echo "  $(basename "$d")"; done
echo "-- USB 设备控制器 --"
for u in /sys/class/udc/*; do [ -e "$u" ] && echo "  UDC $(basename "$u")"; done

# USB ACM 串口 shell：插到电脑上会出现 /dev/ttyACM0（Linux）或 COM 口（Windows 需驱动）
setup_usb_acm() {
  [ -d /sys/kernel/config/usb_gadget ] || return 0
  G=/sys/kernel/config/usb_gadget/natrium
  mkdir -p "$G" 2>/dev/null || return 0
  echo 0x18d1 > "$G/idVendor"; echo 0xd001 > "$G/idProduct"
  mkdir -p "$G/strings/0x409"
  echo "natrium" > "$G/strings/0x409/serialnumber"
  echo "Xiaomi"  > "$G/strings/0x409/manufacturer"
  echo "natrium 6.18 debug shell" > "$G/strings/0x409/product"
  mkdir -p "$G/configs/c.1/strings/0x409"
  echo "acm" > "$G/configs/c.1/strings/0x409/configuration"
  mkdir -p "$G/functions/acm.usb0"
  ln -sf "$G/functions/acm.usb0" "$G/configs/c.1/" 2>/dev/null
  UDC="$(ls /sys/class/udc 2>/dev/null | head -1)"
  [ -n "$UDC" ] && echo "$UDC" > "$G/UDC" 2>/dev/null && echo "USB ACM 已启用 (UDC=$UDC)"
}
setup_usb_acm

# 给 USB 串口挂一个交互 shell（后台），同时保持前台可用
if [ -c /dev/ttyGS0 ]; then
  echo "在 PC 上: screen /dev/ttyACM0 115200  或  minicom"
  setsid sh -c 'exec sh </dev/ttyGS0 >/dev/ttyGS0 2>&1' &
fi

echo
echo "屏幕上的这些 log 说明内核已经跑到用户态 init。"
echo "输入 help 查看 busybox 命令；输入 poweroff 关机（长按电源键亦可）。"
echo

# 前台 shell 绑到控制台(fbcon/tty0)，即使没有键盘也能看到输出
exec setsid cttyhack sh
EOF
chmod +x "$DIR/init"

# 打包成 newc cpio
( cd "$DIR" && find . -print0 | cpio --null -o --format=newc --quiet ) > "$DIR/../initramfs-debug.cpio"
xz -9 -C crc32 -c "$DIR/../initramfs-debug.cpio" > "$OUT"
echo "写出 $OUT ($(stat -c%s "$OUT") bytes)"
echo "cpio 内容:"; ( cd "$DIR" && find . | head -20 ) || true
