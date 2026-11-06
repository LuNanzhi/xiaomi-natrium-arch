#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 构建「日志镜像」：把内核诊断信息写进手机 cache 分区，再自动重启回 LineageOS。
# 屏幕上什么都不显示也能拿到证据（用 adb 读 cache 里的文件）。
# 用法(在 WSL 内): bash build-logger-image.sh <stage 目录>
# ---------------------------------------------------------------------------
set -uo pipefail
STAGE="${1:?用法: build-logger-image.sh <stage 目录>}"
W=/root/ir-logger
rm -rf "$W"; mkdir -p "$W"/{bin,proc,sys,dev,etc,tmp,lib,newroot,mnt/cache}
cp /usr/bin/busybox "$W/bin/busybox"; chmod +x "$W/bin/busybox"
for l in sh ash ls cat echo mount umount dmesg sleep clear grep head tail cut setsid free uname date sync mkdir reboot poweroff; do
  ln -sf /bin/busybox "$W/bin/$l"
done
ln -sf /bin/busybox "$W/init"

cat > "$W/init" <<'INIT'
#!/bin/busybox sh
/bin/busybox --install -s /bin 2>/dev/null
export PATH=/bin:/sbin
mount -t proc none /proc          2>/dev/null
mount -t sysfs none /sys          2>/dev/null
mount -t devtmpfs none /dev       2>/dev/null
mount -t debugfs none /sys/kernel/debug 2>/dev/null

# ---- 只认 PARTNAME=cache，找不到就绝不乱挂分区 ----
CACHE=""
for d in /sys/class/block/*; do
  pn="$(grep -o 'PARTNAME=[^ ]*' "$d/uevent" 2>/dev/null | cut -d= -f2)"
  [ "$pn" = "cache" ] && CACHE="/dev/$(basename "$d")"
done
MOUNTED=no
if [ -n "$CACHE" ]; then
  if mount -t ext4 -o rw "$CACHE" /mnt/cache 2>/dev/null; then MOUNTED=yes
  elif mount -t f2fs -o rw "$CACHE" /mnt/cache 2>/dev/null; then MOUNTED=yes
  fi
fi

LOGF=/mnt/cache/natrium-diag.txt
[ "$MOUNTED" = no ] && LOGF=/tmp/natrium-diag.txt

{
  echo "===== natrium mainline 6.18 诊断 ($(date)) ====="
  echo "--- uname ---"; uname -a
  echo "--- model ---"; cat /proc/device-tree/model 2>/dev/null; echo
  echo "--- cache 分区定位 ---"; echo "CACHE=$CACHE MOUNTED=$MOUNTED"
  echo
  echo "--- /proc/partitions ---"; cat /proc/partitions
  echo
  echo "--- 分区 PARTNAME 表 ---"
  for d in /sys/class/block/*; do
    pn="$(grep -o 'PARTNAME=[^ ]*' "$d/uevent" 2>/dev/null)"
    [ -n "$pn" ] && echo "  $(basename "$d") -> $pn"
  done
  echo
  echo "--- DRM 连接器状态 ---"
  for f in /sys/class/drm/*/status; do [ -e "$f" ] && echo "  $f = $(cat "$f")"; done
  echo "  drm 设备: $(ls /sys/class/drm/ 2>&1 | tr '\n' ' ')"
  echo
  echo "--- 背光 ---"
  ls -l /sys/class/backlight/ 2>&1
  for f in /sys/class/backlight/*/brightness /sys/class/backlight/*/max_brightness /sys/class/backlight/*/bl_power; do
    [ -e "$f" ] && echo "  $f = $(cat "$f" 2>/dev/null)"
  done
  echo
  echo "--- USB 控制器 (/sys/class/udc) ---"
  ls -l /sys/class/udc/ 2>&1
  echo "  dwc3 相关 sysfs:"; ls /sys/bus/platform/drivers/dwc3/ 2>&1
  echo
  echo "--- 稳压器 ---"
  head -50 /sys/kernel/debug/regulator/regulator_summary 2>&1
  echo
  echo "--- 关键驱动是否绑定 ---"
  echo "  mdss/msm:   $(ls -d /sys/bus/platform/drivers/msm* 2>/dev/null | tr '\n' ' ')"
  echo "  panel:      $(ls /sys/bus/platform/drivers/ | grep -i panel | tr '\n' ' ')"
  echo "  rmi4:       $(ls /sys/bus/i2c/drivers/ 2>/dev/null | grep -i rmi | tr '\n' ' ')"
  echo "  wled:       $(ls /sys/bus/platform/drivers/ | grep -i wled | tr '\n' ' ')"
  echo "  ufs:        $(ls /sys/bus/platform/drivers/ | grep -i ufs | tr '\n' ' ')"
  echo
  echo "===== dmesg 全文 ====="
  dmesg
} > "$LOGF" 2>&1

cp "$LOGF" /tmp/natrium-diag.txt 2>/dev/null

# ---- 顺手把背光/LED 点亮（能亮就多一个信号）----
for f in /sys/class/backlight/*/max_brightness; do
  [ -e "$f" ] || continue
  b="${f%max_brightness}brightness"; cat "$f" > "$b" 2>/dev/null
done
for f in /sys/class/leds/*/brightness; do [ -e "$f" ] && echo 255 > "$f" 2>/dev/null; done

# ---- USB ACM（能起来就更方便）----
G=/sys/kernel/config/usb_gadget/d
mkdir -p "$G" 2>/dev/null && {
  echo 0x18d1 > "$G/idVendor"; echo 0xd001 > "$G/idProduct"
  mkdir -p "$G/strings/0x409" "$G/configs/c.1/strings/0x409" "$G/functions/acm.usb0"
  echo natrium > "$G/strings/0x409/serialnumber"; echo Xiaomi > "$G/strings/0x409/manufacturer"
  echo natrium-6.18 > "$G/strings/0x409/product"
  echo diag > "$G/configs/c.1/strings/0x409/configuration"
  ln -sf "$G/functions/acm.usb0" "$G/configs/c.1/" 2>/dev/null
  U="$(ls /sys/class/udc 2>/dev/null | head -1)"
  [ -n "$U" ] && echo "$U" > "$G/UDC" 2>/dev/null
}

sync
sleep 60
echo b > /proc/sysrq-trigger
sleep 10
reboot -f
INIT
chmod +x "$W/init"

( cd "$W" && find . -print0 | cpio --null -o --format=newc --quiet ) | xz -9 -C crc32 > "$STAGE/initramfs-logger.cpio.xz"
echo "initramfs-logger: $(stat -c%s "$STAGE/initramfs-logger.cpio.xz") bytes"

CMD="console=tty0 loglevel=8 ignore_loglevel init=/init rw root=/dev/ram0"
python3 "$STAGE/tools/mk_bootimg.py" \
  --kernel "$STAGE/Image.gz" --dtb "$STAGE/msm8996pro-xiaomi-natrium.dtb" \
  --ramdisk "$STAGE/initramfs-logger.cpio.xz" --cmdline "$CMD" \
  --out "$STAGE/boot-6.18.55-natrium-logger.img" | tail -3
python3 "$STAGE/tools/verify_bootimg.py" "$STAGE/boot-6.18.55-natrium-logger.img" 2>&1 | tail -5
sha256sum "$STAGE/boot-6.18.55-natrium-logger.img"
