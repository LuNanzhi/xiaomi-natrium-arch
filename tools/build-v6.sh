#!/usr/bin/env bash
# v6: v5 + enable dbus (iwd.service is Type=dbus, so without dbus it never starts)
set -uo pipefail
ROOT=/root/arch/root
TOOLS=/mnt/c/Users/江月白/Documents/deepseek-harness/default-workspace/natrium-port/tools

say() { echo "[$(date +%H:%M:%S)] $*"; }

say "== enable dbus =="
mkdir -p "$ROOT/etc/systemd/system/multi-user.target.wants"
ln -sf /usr/lib/systemd/system/dbus.service "$ROOT/etc/systemd/system/multi-user.target.wants/dbus.service"
ls -l "$ROOT/etc/systemd/system/multi-user.target.wants/" | grep -E "dbus|iwd|dhcp"

say "== sanity: dbus-broker + iwd + profile =="
ls -l "$ROOT/usr/bin/dbus-broker" "$ROOT/usr/lib/iwd/iwd" "$ROOT/var/lib/iwd/"*.psk

say "== regenerate image =="
rm -f /root/arch/arch-natrium-v6.img
bash "$TOOLS/build-arch-image.sh" "$ROOT" /root/arch/arch-natrium-v6.img 3G 2>&1 | tail -8
mv -f /mnt/c/Users/Public/natrium/arch/arch-natrium.img /mnt/c/Users/Public/natrium/arch/arch-natrium-v6.img
e2fsck -fn /root/arch/arch-natrium-v6.img >/tmp/v6fsck.log 2>&1 && echo "fsck: clean" || { echo "fsck:"; tail -3 /tmp/v6fsck.log; }
ls -l /mnt/c/Users/Public/natrium/arch/arch-natrium-v6.img
say "ready"
