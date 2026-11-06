#!/usr/bin/env bash
# Build a *correct* diagnostic initramfs for xiaomi-natrium and pack a boot.img.
#
# Why this exists: the earlier bbshell images had /init as a symlink to busybox
# (the `cat > init` went through the link), so the probe script never ran and
# "no output" proved nothing. This one:
#   - writes /init as a real file
#   - ships the USB gadget modules (dwc3/dwc3-qcom/libcomposite/usb_f_acm),
#     decompressed, with a regenerated modules.dep (busybox modprobe can't
#     read .ko.zst)
#   - NEVER reboots: if the phone stays alive instead of coming back to
#     fastboot, the kernel reached init.
#
# Usage: build-probe-initramfs.sh [outdir]
set -uo pipefail

MODS_SRC=${MODS_SRC:-/tmp/kk/lib/modules/6.19.5}
KERNEL=${KERNEL:-/root/art-6195/Image.gz}
DTB=${DTB:-/root/art-6195/msm8996pro-xiaomi-natrium.dtb}
BB=${BB:-/root/busybox-aarch64-static}
OUT=${1:-/root/probe}
TOOLS=${TOOLS:-/mnt/c/Users/江月白/Documents/deepseek-harness/default-workspace/natrium-port/tools}
VER=$(basename "$MODS_SRC")

TARGETS="dwc3 dwc3-qcom udc-core libcomposite usb_f_acm phy-qcom-qusb2 phy-qcom-qmp-combo phy-qcom-qmp-usbc msm panel-sharp-td4722-xcmd"

echo "== 1/6 check inputs =="
for f in "$MODS_SRC/modules.dep" "$KERNEL" "$DTB" "$BB"; do
    [ -e "$f" ] || { echo "!! missing $f"; exit 1; }
done
file -b "$BB" | grep -q aarch64 || { echo "!! busybox is not aarch64"; exit 1; }

echo "== 2/6 resolve module closure =="
python3 - "$MODS_SRC" "$TARGETS" > /tmp/probe-mods.txt <<'PY'
import os, sys
root, targets = sys.argv[1], sys.argv[2].split()
dep = os.path.join(root, "modules.dep")
m = {}
for line in open(dep, encoding="utf-8", errors="replace"):
    line = line.rstrip("\n")
    if not line or ":" not in line:
        continue
    path, _, rest = line.partition(":")
    path = path.strip()
    name = os.path.basename(path).replace(".ko.zst", "").replace(".ko", "")
    m[name] = (path, [os.path.basename(x).replace(".ko.zst", "").replace(".ko", "") for x in rest.split()])
seen, stack = {}, list(targets)
while stack:
    n = stack.pop()
    if n in seen:
        continue
    if n not in m:
        sys.stderr.write("warning: target %s not found in modules.dep\n" % n)
        continue
    seen[n] = m[n][0]
    stack.extend(m[n][1])
for n in sorted(seen):
    print(seen[n])
PY
wc -l < /tmp/probe-mods.txt | xargs echo "  modules in closure:"

echo "== 3/6 stage =="
rm -rf "$OUT"; mkdir -p "$OUT/root"/{bin,sbin,proc,sys,dev,etc,tmp,lib/modules,mnt/cache,root,run}
BBROOT="$OUT/root"
cp "$BB" "$BBROOT/bin/busybox"; chmod 755 "$BBROOT/bin/busybox"
# decompress + copy
while read -r rel; do
    [ -n "$rel" ] || continue
    dst="$BBROOT/lib/modules/$VER/${rel%.zst}"
    mkdir -p "$(dirname "$dst")"
    zstd -d -q -f "$MODS_SRC/$rel" -o "$dst" || exit 1
done < /tmp/probe-mods.txt
echo "  decompressed $(find "$BBROOT/lib/modules/$VER" -name '*.ko' | wc -l) modules"

echo "== 4/6 regenerated modules.dep =="
VERDIR="$BBROOT/lib/modules/$VER"
touch "$VERDIR/modules.order" "$VERDIR/modules.builtin"
depmod -b "$BBROOT" "$VER" 2>/dev/null
grep -c . "$VERDIR/modules.dep" | xargs echo "  dep entries:"

echo "== 5/6 /init =="
cat > "$BBROOT/init" <<'INIT'
#!/bin/busybox sh
/bin/busybox --install -s /bin 2>/dev/null
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
export HOME=/root
mount -t proc     proc     /proc
mount -t sysfs    sysfs    /sys
mount -t devtmpfs devtmpfs /dev 2>/dev/null
mkdir -p /sys/kernel/config /dev/pts
mount -t configfs none /sys/kernel/config 2>/dev/null

LOG=/tmp/probe.txt
run() { echo "--- $* ---" >>"$LOG" 2>&1; "$@" >>"$LOG" 2>&1; }

{
  echo "===== natrium mainline PROBE ====="
  echo "uname  : $(uname -a)"
  echo "cmdline: $(cat /proc/cmdline)"
  echo "model  : $(cat /proc/device-tree/model 2>/dev/null)"
  echo
} > "$LOG"

for m in phy-qcom-qusb2 phy-qcom-qmp-combo phy-qcom-qmp-usbc dwc3 dwc3-qcom udc-core libcomposite usb_f_acm msm panel-sharp-td4722-xcmd; do
  echo "modprobe $m -> $(${BUSYBOX:-modprobe} "$m" 2>&1)" >> "$LOG"
done

echo "--- udc ---" >> "$LOG"; ls /sys/class/udc >> "$LOG" 2>&1
echo "--- drm ---" >> "$LOG"; ls /sys/class/drm >> "$LOG" 2>&1

G=/sys/kernel/config/usb_gadget/natrium
mkdir -p "$G" 2>/dev/null
echo 0x18d1 > "$G/idVendor" 2>/dev/null
echo 0xd001 > "$G/idProduct" 2>/dev/null
mkdir -p "$G/strings/0x409" "$G/configs/c.1/strings/0x409" "$G/functions/acm.usb0" 2>/dev/null
echo natrium     > "$G/strings/0x409/serialnumber" 2>/dev/null
echo Xiaomi      > "$G/strings/0x409/manufacturer" 2>/dev/null
echo natrium-probe > "$G/strings/0x409/product" 2>/dev/null
echo acm         > "$G/configs/c.1/strings/0x409/configuration" 2>/dev/null
ln -sf "$G/functions/acm.usb0" "$G/configs/c.1/" 2>/dev/null
UDC="$(ls /sys/class/udc 2>/dev/null | head -1)"
echo "udc chosen: ${UDC:-(none)}" >> "$LOG"
[ -n "$UDC" ] && echo "$UDC" > "$G/UDC" 2>/dev/null

# keep a copy where Android/pmOS boots can reach it: the cache partition
CACHE=""
for d in /sys/class/block/*; do
  pn="$(grep -o 'PARTNAME=[^ ]*' "$d/uevent" 2>/dev/null | cut -d= -f2)"
  [ "$pn" = "cache" ] && CACHE="/dev/$(basename "$d")"
done
if [ -n "$CACHE" ]; then
  mount -t ext4 -o rw "$CACHE" /mnt/cache 2>/dev/null && {
    echo "cache: $CACHE mounted" >> "$LOG"
    cp "$LOG" /mnt/cache/natrium-probe.txt 2>/dev/null
  }
fi
echo "--- dmesg (tail) ---" >> "$LOG"
dmesg | tail -80 >> "$LOG" 2>&1

# never reboot: proving init was reached = the phone must stay alive
while true; do
  [ -c /dev/ttyGS0 ] && { echo; cat "$LOG"; echo; } > /dev/ttyGS0 2>/dev/null
  sleep 10
done
INIT
chmod 755 "$BBROOT/init"
head -1 "$BBROOT/init"
[ -L "$BBROOT/init" ] && { echo "!! /init is a symlink, abort"; exit 2; }

echo "== 6/6 pack =="
( cd "$BBROOT" && find . -print0 | cpio --null -o -H newc --quiet ) | xz -9 -C crc32 > "$OUT/initramfs-probe.cpio.xz"
echo "  initramfs: $(stat -c%s "$OUT/initramfs-probe.cpio.xz") bytes"
rm -rf "$OUT/check"; mkdir -p "$OUT/check"
( cd "$OUT/check" && xz -dc "$OUT/initramfs-probe.cpio.xz" | cpio -id --quiet 2>/dev/null )
echo "  check /init : $(file -b "$OUT/check/init")"
echo "  check busybox: $(file -b "$OUT/check/bin/busybox")"

python3 "$TOOLS/mk_bootimg.py" \
  --kernel "$KERNEL" \
  --dtb "$DTB" \
  --ramdisk "$OUT/initramfs-probe.cpio.xz" \
  --cmdline "console=tty0 loglevel=8 ignore_loglevel init=/init rw root=/dev/ram0 panic=10" \
  --out "$OUT/boot-probe.img"
ls -l "$OUT/boot-probe.img"
