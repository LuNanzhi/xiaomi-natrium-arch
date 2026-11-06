#!/usr/bin/env bash
# Prepare an Arch Linux ARM aarch64 rootfs for xiaomi-natrium (P0: console + ssh over USB).
#
#   stage 1: unpack the ALARM tarball
#   stage 2: drop in the 6.19.5 kernel modules + natrium firmware
#   stage 3: fstab / hostname / root password / sshd / modules-load / machine-id
#
# Nothing here touches the phone. Usage:
#   prepare-arch-rootfs.sh [rootdir]
set -uo pipefail

TARBALL=${TARBALL:-/mnt/c/Users/Public/natrium/arch/ArchLinuxARM-aarch64-latest.tar.gz}
MODSRC=${MODSRC:-/root/kmods/lib/modules/6.19.5}
FW=${FW:-/mnt/c/Users/Public/natrium/firmware/lib/firmware}
ROOT=${1:-/root/arch/root}
VER=6.19.5

say() { echo "[$(date +%H:%M:%S)] $*"; }

say "== 0) checks =="
[ -s "$TARBALL" ] || { echo "!! tarball missing"; exit 1; }
echo "  tarball: $(stat -c%s "$TARBALL") bytes"

if [ ! -f "$ROOT/etc/os-release" ]; then
    say "== 1) unpack (takes a few minutes) =="
    rm -rf "$ROOT"; mkdir -p "$ROOT"
    tar -xzf "$TARBALL" -C "$ROOT" --numeric-owner || { echo "!! unpack failed"; exit 1; }
else
    say "== 1) already unpacked, skipping =="
fi
say "  rootfs size: $(du -sh "$ROOT" | cut -f1)"

say "== 2) kernel modules $VER =="
mkdir -p "$ROOT/lib/modules"
[ -d "$MODSRC" ] || { echo "!! modules missing at $MODSRC"; exit 1; }
rm -rf "$ROOT/lib/modules/$VER"
cp -a "$MODSRC" "$ROOT/lib/modules/$VER"
# the packaged modules.dep was empty; regenerate so modprobe autoloads deps
depmod -b "$ROOT" "$VER" 2>/dev/null
say "  modules: $(find "$ROOT/lib/modules/$VER" -name '*.ko*' | wc -l), dep lines: $(grep -c . "$ROOT/lib/modules/$VER/modules.dep" 2>/dev/null)"

say "== 3) firmware =="
mkdir -p "$ROOT/lib/firmware"
[ -d "$FW" ] && cp -a "$FW/." "$ROOT/lib/firmware/" && say "  firmware copied: $(find "$ROOT/lib/firmware/qcom" -type f 2>/dev/null | wc -l) qcom files"

say "== 4) base config =="
echo natrium > "$ROOT/etc/hostname"
cat > "$ROOT/etc/fstab" <<'EOF'
# <file system>            <dir>  <type>  <options>          <dump> <pass>
PARTLABEL=userdata         /      ext4    rw,relatime        0      1
EOF
# root password: "arch"  (hash generated on the host, no chroot needed)
HASH=$(openssl passwd -6 -salt natrium arch)
sed -i "s|^root:[^:]*:|root:${HASH}:|" "$ROOT/etc/shadow"
grep -q '^root:' "$ROOT/etc/shadow" || echo "root:${HASH}:0:0:99999:7:::" >> "$ROOT/etc/shadow"

# a real machine-id, so systemd-firstboot does not ask questions on the console
head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$ROOT/etc/machine-id"
echo "  machine-id: $(cat "$ROOT/etc/machine-id")"

# load the display stack early (DRM_MSM is =m in the pmOS kernel config)
cat > "$ROOT/etc/modules-load.d/natrium.conf" <<'EOF'
# display: DRM_MSM is =m in the pmOS kernel config, and so is the WLED
# backlight (without leds-qcom-lpg the console renders but the panel stays dark)
drm
msm
panel-sharp-td4722-xcmd
leds-qcom-lpg
EOF

# ssh: root login with password on the usb/rndis link
mkdir -p "$ROOT/etc/ssh/sshd_config.d"
cat > "$ROOT/etc/ssh/sshd_config.d/10-natrium.conf" <<'EOF'
PermitRootLogin yes
PasswordAuthentication yes
EOF
ln -sf /usr/lib/systemd/system/sshd.service "$ROOT/etc/systemd/system/multi-user.target.wants/sshd.service"

# keep pacman from pulling a generic kernel and replacing our /boot
cat > "$ROOT/etc/pacman.conf.d-note" <<'EOF'
NOTE: the kernel comes from the boot partition (built outside Arch).
Do not install linux-aarch64-dtb / linux-aarch64 and do not run mkinitcpio.
EOF

say "== done =="
du -sh "$ROOT"
ls "$ROOT"
