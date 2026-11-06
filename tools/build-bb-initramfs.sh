#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 用真正的 aarch64 静态 busybox 做一个「标准 initramfs」（带 USB 串口 shell）
#   - busybox 来自 Alpine 的 busybox-static 包（已下载到 /root/busybox-aarch64-static）
#   - init 脚本：挂载文件系统 → 配 USB ACM 串口 → 找 cache 分区写日志 → 在串口上开 shell
#   - 每 20 秒把报告重发一次串口（CDC-ACM 开端口前写的数据会丢）
# 用法: build-bb-initramfs.sh <stage 目录> <目标标签>
# ---------------------------------------------------------------------------
set -uo pipefail
STAGE="${1:?用法: build-bb-initramfs.sh <stage> <tag>}"
TAG="${2:?need tag}"
BB=/root/busybox-aarch64-static
W=/root/bb-ir

[ -x "$BB" ] || { echo "!! 缺少静态 busybox: $BB"; exit 1; }
INFO="$(file -b "$BB")"
echo "busybox: $INFO"
case "$INFO" in
  *ARM*aarch64*) echo "  ok: aarch64" ;;
  *) echo "  !! 架构不对"; exit 2 ;;
esac

rm -rf "$W"; mkdir -p "$W/root"/{bin,sbin,proc,sys,dev,etc,tmp,lib,mnt/cache,root}
cp "$BB" "$W/root/bin/busybox"
chmod 755 "$W/root/bin/busybox"
for l in sh ash ls cat echo mount umount dmesg sleep clear grep head tail cut setsid cttyhack free uname date sync mkdir reboot poweroff ln cp mv rm chmod vi ifconfig ip; do
  ln -sf /bin/busybox "$W/root/bin/$l"
done
ln -sf /bin/busybox "$W/root/init"

cat > "$W/root/init" <<'INIT'
#!/bin/busybox sh
/bin/busybox --install -s /bin 2>/dev/null
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
export HOME=/root

mount -t proc none /proc 2>/dev/null
mount -t sysfs none /sys 2>/dev/null
mount -t devtmpfs none /dev 2>/dev/null
mount -t debugfs none /sys/kernel/debug 2>/dev/null
mount -t configfs none /sys/kernel/config 2>/dev/null

REPORT=/tmp/natrium-report.txt
LOGFILE=""

# ---- USB ACM 串口 gadget ----
G=/sys/kernel/config/usb_gadget/natrium
if [ -d /sys/kernel/config/usb_gadget ]; then
  mkdir -p "$G" 2>/dev/null
  echo 0x18d1 > "$G/idVendor" 2>/dev/null
  echo 0xd001 > "$G/idProduct" 2>/dev/null
  mkdir -p "$G/strings/0x409" "$G/configs/c.1/strings/0x409" "$G/functions/acm.usb0" 2>/dev/null
  echo natrium  > "$G/strings/0x409/serialnumber" 2>/dev/null
  echo Xiaomi   > "$G/strings/0x409/manufacturer" 2>/dev/null
  echo natrium-mainline > "$G/strings/0x409/product" 2>/dev/null
  echo acm      > "$G/configs/c.1/strings/0x409/configuration" 2>/dev/null
  ln -sf "$G/functions/acm.usb0" "$G/configs/c.1/" 2>/dev/null
  UDC="$(ls /sys/class/udc 2>/dev/null | head -1)"
  [ -n "$UDC" ] && echo "$UDC" > "$G/UDC" 2>/dev/null
fi

# ---- 背光 / LED 拉满（可见信号）----
for f in /sys/class/backlight/*/max_brightness; do
  [ -e "$f" ] || continue
  b="${f%max_brightness}brightness"; cat "$f" > "$b" 2>/dev/null
done
for f in /sys/class/leds/*/brightness; do [ -e "$f" ] && echo 255 > "$f" 2>/dev/null; done

# ---- 找 cache 分区（PARTNAME=cache，或按 256MiB 容量兜底）----
CACHE=""
for d in /sys/class/block/*; do
  pn="$(grep -o 'PARTNAME=[^ ]*' "$d/uevent" 2>/dev/null | cut -d= -f2)"
  [ "$pn" = "cache" ] && CACHE="/dev/$(basename "$d")"
done
if [ -z "$CACHE" ]; then
  for d in /sys/class/block/*; do
    sz="$(cat "$d/size" 2>/dev/null)"
    [ "$sz" = "524288" ] && CACHE="/dev/$(basename "$d")"
  done
fi
CACHEMNT=no
if [ -n "$CACHE" ]; then
  mkdir -p /mnt/cache
  mount -t ext4 -o rw "$CACHE" /mnt/cache 2>/dev/null && CACHEMNT=yes
fi
[ "$CACHEMNT" = yes ] && LOGFILE=/mnt/cache/natrium-diag.txt || LOGFILE=/tmp/natrium-diag.txt

# ---- 生成报告 ----
{
  echo "===== natrium mainline bring-up (busybox initramfs) ====="
  echo "date        : $(date)"
  echo "uname       : $(uname -a)"
  echo "cache dev   : ${CACHE:-(none)} mounted=$CACHEMNT"
  echo "cmdline     : $(cat /proc/cmdline)"
  echo
  echo "--- partitions ---"; cat /proc/partitions
  echo "--- PARTNAME ---"
  for d in /sys/class/block/*; do
    pn="$(grep -o 'PARTNAME=[^ ]*' "$d/uevent" 2>/dev/null)"
    [ -n "$pn" ] && echo "  $(basename "$d") -> $pn"
  done
  echo "--- DRM ---"; ls /sys/class/drm/ 2>&1
  for f in /sys/class/drm/*/status; do [ -e "$f" ] && echo "  $f = $(cat "$f")"; done
  echo "--- backlight ---"; ls /sys/class/backlight/ 2>&1
  for f in /sys/class/backlight/*/brightness /sys/class/backlight/*/max_brightness; do
    [ -e "$f" ] && echo "  $f = $(cat "$f" 2>/dev/null)"; done
  echo "--- udc ---"; ls /sys/class/udc/ 2>&1
  echo "--- regulator ---"; head -40 /sys/kernel/debug/regulator/regulator_summary 2>&1
  echo "--- device-tree model ---"; cat /proc/device-tree/model 2>/dev/null; echo
  echo
  echo "===== dmesg ====="
  dmesg
} > "$REPORT" 2>&1
[ "$LOGFILE" != "$REPORT" ] && cp "$REPORT" "$LOGFILE" 2>/dev/null

# ---- 后台：每 20 秒把报告重发到串口（主机可能在端口打开前就错过了）----
if [ -c /dev/ttyGS0 ]; then
  (
    while true; do
      printf '\r\n===== NATRIUM REPORT BEGIN =====\r\n' > /dev/ttyGS0 2>/dev/null
      cat "$REPORT" > /dev/ttyGS0 2>/dev/null
      printf '\r\n===== NATRIUM REPORT END =====\r\n' > /dev/ttyGS0 2>/dev/null
      sleep 20
    done
  ) &
fi

sync
sleep 2

# ---- 在串口上开 shell（插到电脑上就是 COM 口，能直接敲命令）----
if [ -c /dev/ttyGS0 ]; then
  printf '\r\n*** natrium: 串口 shell 已就绪，可直接输入命令 (输入 help 查看 busybox) ***\r\n' > /dev/ttyGS0 2>/dev/null
  exec setsid cttyhack sh
fi

# ---- 没有串口可用时的兜底行为 ----
sleep 20
sync
reboot -f
INIT
chmod 755 "$W/root/init"

( cd "$W/root" && find . -print0 | cpio --null -o -H newc --quiet ) | xz -9 -C crc32 > "$W/initramfs-bb.cpio.xz"
echo "initramfs: $(stat -c%s "$W/initramfs-bb.cpio.xz") bytes"

# 校验包内 busybox 架构
rm -rf "$W/check"; mkdir -p "$W/check"
( cd "$W/check" && xz -dc "$W/initramfs-bb.cpio.xz" | cpio -id --quiet 2>/dev/null )
echo "包内 busybox: $(file -b "$W/check/bin/busybox" 2>/dev/null)"
case "$(file -b "$W/check/bin/busybox" 2>/dev/null)" in
  *ARM*aarch64*) echo "  ✅ 架构正确" ;;
  *) echo "  ❌ 架构不对，终止"; exit 3 ;;
esac

echo
echo "### 打包镜像 tag=$TAG"
for pair in /root/art-6195 /root/art-6187 /root/art-6.12.10 /root/art-6.17.8; do
  [ -f "$pair/Image.gz" ] || continue
  v="$(basename "$pair" | sed 's/^art-//')"
  out="$STAGE/boot-$v-bbshell.img"
  python3 "$STAGE/tools/mk_bootimg.py" \
    --kernel "$pair/Image.gz" \
    --dtb "$pair/msm8996pro-xiaomi-natrium.dtb" \
    --ramdisk "$W/initramfs-bb.cpio.xz" \
    --cmdline "console=tty0 loglevel=8 ignore_loglevel init=/init rw root=/dev/ram0 panic=10" \
    --out "$out" >/dev/null && printf '  %-40s %9d bytes\n' "$(basename "$out")" "$(stat -c%s "$out")"
done
echo "=== done ==="
