#!/usr/bin/env bash
# Build the Arch boot.img for xiaomi-natrium:
#   kernel + sharp-panel DTB  <- taken verbatim from the pmOS 6.19.5 image
#   ramdisk                   <- our own busybox initramfs (rootfs finder)
#   cmdline                   <- rewritten for Arch
#
# Also installs the gadget/networkd files into the rootfs and rebuilds the image.
#
# Usage: build-arch-bootimg.sh [--no-image]
set -uo pipefail

REPO=/mnt/c/Users/江月白/Documents/deepseek-harness/default-workspace/natrium-port
TOOLS=$REPO/tools
AF=$REPO/arch-files
ROOT=/root/arch/root
IMG=/root/arch/arch-natrium.img
PMBOOT=/mnt/c/Users/Public/natrium/pmos/boot.img
OUT=/mnt/c/Users/Public/natrium/arch
CMDLINE="console=tty0 loglevel=7 ignore_loglevel root=PARTLABEL=userdata rootwait rw init=/init panic=10"

say() { echo "[$(date +%H:%M:%S)] $*"; }

say "== 1) install arch-files into rootfs =="
install -Dm755 "$AF/natrium-usb-gadget"          "$ROOT/usr/local/sbin/natrium-usb-gadget"
install -Dm644 "$AF/natrium-usb-gadget.service"  "$ROOT/etc/systemd/system/natrium-usb-gadget.service"
install -Dm644 "$AF/20-usb0.network"             "$ROOT/etc/systemd/network/20-usb0.network"
mkdir -p "$ROOT/etc/systemd/system/multi-user.target.wants"
ln -sf /etc/systemd/system/natrium-usb-gadget.service "$ROOT/etc/systemd/system/multi-user.target.wants/natrium-usb-gadget.service"
ln -sf /usr/lib/systemd/system/systemd-networkd.service "$ROOT/etc/systemd/system/multi-user.target.wants/systemd-networkd.service"
echo "  gadget script : $(ls -l "$ROOT/usr/local/sbin/natrium-usb-gadget" | awk '{print $1, $5}')"
echo "  unit          : $(basename "$(readlink -f "$ROOT/etc/systemd/system/multi-user.target.wants/natrium-usb-gadget.service")")"
echo "  networkd      : $(basename "$(readlink -f "$ROOT/etc/systemd/system/multi-user.target.wants/systemd-networkd.service")")"

say "== 2) initramfs =="
IR=/root/arch/ir
rm -rf "$IR"; mkdir -p "$IR"/{bin,proc,sys,dev,newroot,tmp,etc,run,lib}
cp /root/busybox-aarch64-static "$IR/bin/busybox"; chmod 755 "$IR/bin/busybox"
cp "$AF/init" "$IR/init"; chmod 755 "$IR/init"
file -b "$IR/bin/busybox" | grep -q aarch64 || { echo "!! busybox not aarch64"; exit 1; }
[ -f "$IR/init" ] && [ ! -L "$IR/init" ] || { echo "!! /init is not a regular file"; exit 1; }
( cd "$IR" && find . -print0 | cpio --null -o -H newc --quiet ) | xz -9 -C crc32 > /root/arch/arch-initramfs.cpio.xz
say "  initramfs: $(stat -c%s /root/arch/arch-initramfs.cpio.xz) bytes"

say "== 3) repack boot.img =="
rm -rf /root/arch/pmboot; mkdir -p /root/arch/pmboot
python3 "$TOOLS/bootimg_info.py" unpack "$PMBOOT" /root/arch/pmboot >/dev/null || { echo "!! unpack failed"; exit 1; }
python3 - /root/arch/pmboot/header.json "$CMDLINE" <<'PY'
import json, sys
p, cmd = sys.argv[1], sys.argv[2]
m = json.load(open(p))
m["cmdline"] = cmd
m["extra_cmdline"] = ""
json.dump(m, open(p, "w"), indent=2)
print("  cmdline ->", cmd)
PY
cp /root/arch/arch-initramfs.cpio.xz /root/arch/pmboot/ramdisk.img
python3 "$TOOLS/bootimg_info.py" repack /root/arch/pmboot /root/arch/boot-arch.img || { echo "!! repack failed"; exit 1; }
say "  boot-arch.img: $(stat -c%s /root/arch/boot-arch.img) bytes"

say "== 4) verify =="
python3 "$TOOLS/verify_bootimg.py" /root/arch/boot-arch.img 2>&1 | grep -E "cmdline|版本串|compatible|DTB|ramdisk|init|sharp|通过" | head -15
strings /root/arch/boot-arch.img | grep -q 'sharp,td4722-xcmd' && echo "  panel: sharp,td4722-xcmd OK" || echo "  !! panel string missing"

say "== 5) rebuild rootfs image =="
if [ "${1:-}" != "--no-image" ]; then
    bash "$TOOLS/build-arch-image.sh" "$ROOT" "$IMG" 3G | tail -8
fi

mkdir -p "$OUT"
cp /root/arch/boot-arch.img "$OUT/boot-arch.img" && say "  copied boot-arch.img"
cp /root/arch/arch-initramfs.cpio.xz "$OUT/arch-initramfs.cpio.xz"
ls -l "$OUT"
say "== done =="
