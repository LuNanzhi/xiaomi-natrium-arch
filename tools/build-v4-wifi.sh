#!/usr/bin/env bash
# v4: give the installed Arch image WiFi so we can reach it over the LAN.
#
#   - installs iwd (+ ell) into the rootfs by extracting ALARM packages
#     (no chroot, no qemu needed)
#   - writes the iwd profile for the given SSID/PSK
#   - enables iwd + dhcpcd on wlp1s0
#   - drops phy-qcom-qmp-* from modules-load (they trigger the enable_irq oops)
#   - keeps the console debug dump, now clearing the screen first
#
# Usage: build-v4-wifi.sh "<SSID>" "<PSK>" [src.img] [out.img]
set -uo pipefail
SSID=${1:?usage: build-v4-wifi.sh "<SSID>" "<PSK>"}
PSK=${2:?usage: build-v4-wifi.sh "<SSID>" "<PSK>"}
SRC=${3:-/root/arch/arch-natrium.img}
DST=${4:-/root/arch/arch-natrium-wifi.img}
PKGS=/root/arch/pkgs
MNT=/mnt/archwifi

[ -f "$PKGS/iwd.pkg" ] || { echo "!! iwd.pkg missing (download first)"; exit 1; }
if [ ! -f "$PKGS/ell.pkg" ]; then
    u=https://mirror.nju.edu.cn/archlinuxarm/aarch64/extra/
    f=$(curl -sL --max-time 30 "$u" | grep -oE "ell-[^\"]+pkg\.tar\.xz" | sort -u | head -1)
    echo "downloading ell: $f"
    curl -sL --max-time 60 -o "$PKGS/ell.pkg" "$u$f"
fi

cp "$SRC" "$DST"
mkdir -p "$MNT"
mount -o loop "$DST" "$MNT" || { echo "mount failed"; exit 1; }

echo "== install iwd + ell =="
for p in "$PKGS/iwd.pkg" "$PKGS/ell.pkg"; do
    tmp=$(mktemp -d)
    tar -xf "$p" -C "$tmp" 2>/dev/null
    ( cd "$tmp" && tar -cf - usr 2>/dev/null ) | ( cd "$MNT" && tar -xf - 2>/dev/null )
    rm -rf "$tmp"
done
ls -l "$MNT/usr/lib/iwd/iwd" "$MNT/usr/lib/libell.so" 2>&1 | head -3

echo "== iwd profile =="
mkdir -p "$MNT/var/lib/iwd"
cat > "$MNT/var/lib/iwd/${SSID}.psk" <<EOF
[Security]
PreSharedKey=${PSK}

[Settings]
AutoConnect=true
EOF
echo "  profile written: /var/lib/iwd/${SSID}.psk (psk length ${#PSK})"

echo "== services =="
mkdir -p "$MNT/etc/systemd/system/multi-user.target.wants"
ln -sf /usr/lib/systemd/system/iwd.service "$MNT/etc/systemd/system/multi-user.target.wants/iwd.service"
mkdir -p "$MNT/etc/systemd/system/multi-user.target.wants"
ln -sf /usr/lib/systemd/system/dhcpcd@.service \
       "$MNT/etc/systemd/system/multi-user.target.wants/dhcpcd@wlp1s0.service"

echo "== drop crashing PHY modules =="
cat > "$MNT/etc/modules-load.d/natrium.conf" <<'EOF'
# display
drm
msm
panel-sharp-td4722-xcmd
leds-qcom-lpg
# NOTE: phy-qcom-qmp-combo / phy-qcom-qmp-usbc are deliberately NOT loaded:
# they oops (enable_irq, unbalanced IRQ 70) in a kworker on this kernel.
EOF

echo "== debug dump: clear screen first =="
sed -i '2i printf "\\033[2J\\033[H" > /dev/tty0 2>/dev/null' "$MNT/usr/local/sbin/natrium-debug" 2>/dev/null || true

sync
umount "$MNT"
e2fsck -f -y "$DST" >/dev/null 2>&1
cp "$DST" /mnt/c/Users/Public/natrium/arch/arch-natrium-wifi.img
echo "ready: /mnt/c/Users/Public/natrium/arch/arch-natrium-wifi.img"
