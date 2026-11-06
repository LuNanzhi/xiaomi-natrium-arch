#!/usr/bin/env bash
# Build the Arch Linux ARM rootfs image for xiaomi-natrium.
# Produces a plain ext4 image (no partition table) meant for the userdata partition.
#
# Usage: build-arch-image.sh [rootfs] [out.img] [size]
set -uo pipefail

ROOT=${1:-/root/arch/root}
IMG=${2:-/root/arch/arch-natrium.img}
SIZE=${3:-3G}
MNT=/mnt/archroot

say() { echo "[$(date +%H:%M:%S)] $*"; }

say "== 0) sanity check of the rootfs =="
for f in etc/os-release etc/shadow etc/fstab etc/machine-id usr/lib/systemd/systemd; do
    [ -e "$ROOT/$f" ] || { echo "!! missing $ROOT/$f"; exit 1; }
done
echo "  os-release : $(grep -E '^PRETTY_NAME' "$ROOT/etc/os-release")"
echo "  fstab      : $(grep -v '^#' "$ROOT/etc/fstab" | grep -v '^$' | head -1)"
echo "  root hash  : $(grep '^root:' "$ROOT/etc/shadow" | cut -d: -f2 | cut -c1-12)..."
echo "  modules    : $(find "$ROOT/lib/modules/6.19.5" -name '*.ko*' | wc -l)"
echo "  msm deps   : $(grep -c 'drm_kms_helper' "$ROOT/lib/modules/6.19.5/modules.dep" 2>/dev/null) refs"
echo "  sshd link  : $(readlink -f "$ROOT/etc/systemd/system/multi-user.target.wants/sshd.service" 2>/dev/null)"

say "== 1) create $SIZE ext4 image =="
rm -f "$IMG"
truncate -s "$SIZE" "$IMG" || exit 1
mke2fs -t ext4 -b 4096 -F -L archroot -E lazy_itable_init=0,lazy_journal_init=0 "$IMG" >/dev/null 2>&1 || {
    echo "!! mke2fs failed"; exit 1; }
echo "  image: $(stat -c%s "$IMG") bytes"

say "== 2) populate =="
mkdir -p "$MNT"
mount -o loop "$IMG" "$MNT" || { echo "!! loop mount failed"; exit 1; }
( cd "$ROOT" && tar -cf - . 2>/dev/null ) | ( cd "$MNT" && tar -xf - 2>/dev/null )
rc=$?
sync
sleep 1
umount "$MNT" || { echo "!! umount failed"; exit 1; }
[ $rc -eq 0 ] || { echo "!! copy failed"; exit 1; }

say "== 3) fsck + usage =="
e2fsck -f -y "$IMG" >/tmp/arch-fsck.log 2>&1
tail -3 /tmp/arch-fsck.log
dumpe2fs -h "$IMG" 2>/dev/null | grep -E 'Block count|Free blocks|Block size'

say "== 4) copy next to the phone tools =="
cp "$IMG" /mnt/c/Users/Public/natrium/arch/arch-natrium.img && say "  copied"
ls -l /mnt/c/Users/Public/natrium/arch/
say "== done =="
