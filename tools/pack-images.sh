#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 用已经编译好的 6.18.7-msm8996 内核打包三种镜像（不重新编译）：
#   boot-6.18.7msm8996-shell.img   正常 shell（背光 + LED + USB 串口），不自重启
#   boot-6.18.7msm8996-diag.img    20 秒自重启（判定内核是否到用户态）
#   boot-6.18.7msm8996-logger.img  把 dmesg 写进 cache 分区后自重启
# 用法: pack-images.sh <stage 目录> <artifacts 目录>
# ---------------------------------------------------------------------------
set -uo pipefail
STAGE="${1:?用法: pack-images.sh <stage> <artifacts> [tag] [label]}"
ART="${2:-/root/msm8996-artifacts}"
TAG="${3:-6.18.7msm8996}"
LABEL="${4:-6.18.7-msm8996}"

[ -f "$ART/Image.gz" ] || { echo "!! 缺少 $ART/Image.gz"; exit 1; }
[ -f "$ART/msm8996pro-xiaomi-natrium.dtb" ] || { echo "!! 缺少 DTB"; exit 1; }
echo "内核: $(stat -c%s "$ART/Image.gz") bytes, DTB: $(stat -c%s "$ART/msm8996pro-xiaomi-natrium.dtb") bytes"

# ---------- 公共头：挂载文件系统、背光、LED、USB gadget ----------
mk_head() {   # mk_head <文件> <写日志到 cache? yes/no>
  local f="$1" cache="$2"
  {
    echo '#!/bin/busybox sh'
    echo '/bin/busybox --install -s /bin 2>/dev/null'
    echo 'export PATH=/bin:/sbin'
    echo 'mount -t proc none /proc 2>/dev/null'
    echo 'mount -t sysfs none /sys 2>/dev/null'
    echo 'mount -t devtmpfs none /dev 2>/dev/null'
    echo 'mount -t debugfs none /sys/kernel/debug 2>/dev/null'
    if [ "$cache" = yes ]; then
      echo 'CACHE=""; SCAN=""; for d in /sys/class/block/*; do pn="$(grep -o "PARTNAME=[^ ]*" "$d/uevent" 2>/dev/null | cut -d= -f2)"; SCAN="$SCAN $(basename "$d"):$pn"; [ "$pn" = "cache" ] && CACHE="/dev/$(basename "$d")"; done'
      echo '# PARTNAME 拿不到时，按分区大小兜底（cache = 256MiB = 524288 个 512 字节扇区）'
      echo '[ -z "$CACHE" ] && for d in /sys/class/block/*; do sz="$(cat "$d/size" 2>/dev/null)"; [ "$sz" = "524288" ] && CACHE="/dev/$(basename "$d")"; done'
      echo 'mkdir -p /mnt/cache; MOUNTED=no'
      echo '[ -n "$CACHE" ] && { mount -t ext4 -o rw "$CACHE" /mnt/cache 2>/dev/null && MOUNTED=yes; }'
      echo 'LOGF=/mnt/cache/natrium-diag.txt; [ "$MOUNTED" = no ] && LOGF=/tmp/natrium-diag.txt'
      echo '{'
      echo '  echo "===== natrium '"$LABEL"' 诊断 $(date) ====="'
      echo '  echo "CACHE=$CACHE MOUNTED=$MOUNTED"'
      echo '  echo "分区扫描:$SCAN"'
      echo '  uname -a; echo; cat /proc/device-tree/model; echo'
      echo '  echo "--- 分区 ---"; cat /proc/partitions'
      echo '  for d in /sys/class/block/*; do pn="$(grep -o "PARTNAME=[^ ]*" "$d/uevent" 2>/dev/null)"; [ -n "$pn" ] && echo "  $(basename "$d") -> $pn"; done'
      echo '  echo "--- DRM ---"; for f in /sys/class/drm/*/status; do [ -e "$f" ] && echo "  $f = $(cat "$f")"; done; ls /sys/class/drm/ 2>&1'
      echo '  echo "--- 背光 ---"; ls -l /sys/class/backlight/ 2>&1; for f in /sys/class/backlight/*/brightness /sys/class/backlight/*/max_brightness; do [ -e "$f" ] && echo "  $f = $(cat "$f" 2>/dev/null)"; done'
      echo '  echo "--- udc ---"; ls -l /sys/class/udc/ 2>&1'
      echo '  echo "--- regulator ---"; head -40 /sys/kernel/debug/regulator/regulator_summary 2>&1'
      echo '  echo "===== dmesg ====="; dmesg'
      echo '} > "$LOGF" 2>&1'
      echo 'cp "$LOGF" /tmp/natrium-diag.txt 2>/dev/null'
    fi
    echo 'for f in /sys/class/backlight/*/max_brightness; do b="${f%max_brightness}brightness"; cat "$f" > "$b" 2>/dev/null; done'
    echo 'for f in /sys/class/leds/*/brightness; do echo 255 > "$f" 2>/dev/null; done'
    echo 'G=/sys/kernel/config/usb_gadget/d; mkdir -p "$G" 2>/dev/null && {'
    echo '  echo 0x18d1 > "$G/idVendor"; echo 0xd001 > "$G/idProduct"'
    echo '  mkdir -p "$G/strings/0x409" "$G/configs/c.1/strings/0x409" "$G/functions/acm.usb0"'
    echo '  echo natrium > "$G/strings/0x409/serialnumber"; echo Xiaomi > "$G/strings/0x409/manufacturer"; echo natrium-6.18.7 > "$G/strings/0x409/product"'
    echo '  echo diag > "$G/configs/c.1/strings/0x409/configuration"'
    echo '  ln -sf "$G/functions/acm.usb0" "$G/configs/c.1/" 2>/dev/null'
    echo '  U="$(ls /sys/class/udc 2>/dev/null | head -1)"; [ -n "$U" ] && echo "$U" > "$G/UDC" 2>/dev/null'
    echo '}'
    echo 'echo "natrium 6.18.7 init 已运行" > /dev/kmsg 2>/dev/null'
  } > "$f"
}

mk_variant() {   # mk_variant <名字> <cache写日志 yes/no> <尾部模式 shell|diag|logger>
  local name="$1"
  local cache="$2"
  local tail_mode="$3"
  local W="/root/ir-$name"
  rm -rf "$W"
  mkdir -p "$W"/{bin,proc,sys,dev,etc,tmp,lib,newroot,mnt/cache}
  cp /usr/bin/busybox "$W/bin/busybox"
  chmod +x "$W/bin/busybox"
  for l in sh ash ls cat echo mount umount dmesg sleep clear grep head tail cut setsid cttyhack free uname date sync mkdir reboot poweroff; do
    ln -sf /bin/busybox "$W/bin/$l"
  done
  ln -sf /bin/busybox "$W/init"
  mk_head "$W/init" "$cache"
  case "$tail_mode" in
    diag)
      echo 'sleep 20' >> "$W/init"
      echo 'echo b > /proc/sysrq-trigger' >> "$W/init"
      ;;
    logger)
      echo 'sync' >> "$W/init"
      echo 'sleep 60' >> "$W/init"
      echo 'echo b > /proc/sysrq-trigger' >> "$W/init"
      ;;
    flash)
      # 写完日志后关机：信号明确，且不会像 reboot 那样形成重启循环
      echo 'sync' >> "$W/init"
      echo 'sleep 30' >> "$W/init"
      echo 'poweroff -f 2>/dev/null' >> "$W/init"
      echo 'echo o > /proc/sysrq-trigger' >> "$W/init"
      ;;
    shell)
      echo '[ -c /dev/ttyGS0 ] && setsid sh -c "exec sh </dev/ttyGS0 >/dev/ttyGS0 2>&1" &' >> "$W/init"
      echo 'exec setsid cttyhack sh' >> "$W/init"
      ;;
  esac
  chmod +x "$W/init"
  ( cd "$W" && find . -print0 | cpio --null -o --format=newc --quiet ) | xz -9 -C crc32 > "$ART/initramfs-$name.cpio.xz"
  echo "  initramfs-$name: $(stat -c%s "$ART/initramfs-$name.cpio.xz") bytes"
}

echo
echo "### 生成四个 initramfs"
mk_variant shell  no  shell
mk_variant diag   no  diag
mk_variant logger yes logger
mk_variant flash  yes flash

echo
echo "### 打包 boot.img"
CMD="console=tty0 loglevel=8 ignore_loglevel init=/init rw root=/dev/ram0 panic=10 hung_task_panic=1 softlockup_panic=1"
for v in shell diag logger flash; do
  out="$STAGE/boot-$TAG-$v.img"
  python3 "$STAGE/tools/mk_bootimg.py" \
    --kernel "$ART/Image.gz" --dtb "$ART/msm8996pro-xiaomi-natrium.dtb" \
    --ramdisk "$ART/initramfs-$v.cpio.xz" --cmdline "$CMD" \
    --out "$out" | tail -2
  python3 "$STAGE/tools/verify_bootimg.py" "$out" 2>&1 | tail -3
  sha256sum "$out"
done
echo
ls -lh "$STAGE"/boot-$TAG-*.img
