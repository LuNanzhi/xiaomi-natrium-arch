#!/usr/bin/env bash
# v5: WiFi + debug, built the reliable way - install into the rootfs *directory*
# and regenerate the ext4 image from scratch (patching a loop-mounted image
# corrupted the filesystem: "Bad message" on /usr/lib/iwd).
#
# Usage: build-v5.sh [ssid-file]
set -uo pipefail
ROOT=/root/arch/root
PKGS=/root/arch/pkgs
TOOLS=/mnt/c/Users/江月白/Documents/deepseek-harness/default-workspace/natrium-port/tools
AF=/mnt/c/Users/江月白/Documents/deepseek-harness/default-workspace/natrium-port/arch-files
WIFI=${1:-/root/arch/wifi.txt}

SSID=$(sed -n 1p "$WIFI" | tr -d '\r')
PSK=$(sed -n 2p "$WIFI" | tr -d '\r')
[ -n "$SSID" ] && [ -n "$PSK" ] || { echo "!! bad wifi file"; exit 1; }

say() { echo "[$(date +%H:%M:%S)] $*"; }

say "== 1) iwd + ell into rootfs =="
for p in "$PKGS/iwd.pkg" "$PKGS/ell.pkg"; do
    tmp=$(mktemp -d)
    tar -xf "$p" -C "$tmp" 2>/dev/null || { echo "!! extract failed: $p"; exit 1; }
    cp -a "$tmp/usr/." "$ROOT/usr/"
    rm -rf "$tmp"
done
ls -l "$ROOT/usr/lib/iwd/iwd" "$ROOT/usr/lib/libell.so.0.0.2"

say "== 2) iwd profile =="
mkdir -p "$ROOT/var/lib/iwd"
printf '[Security]\nPreSharedKey=%s\n\n[Settings]\nAutoConnect=true\n' "$PSK" > "$ROOT/var/lib/iwd/${SSID}.psk"
chmod 600 "$ROOT/var/lib/iwd/${SSID}.psk"
echo "  profile: /var/lib/iwd/${SSID}.psk (psk len ${#PSK})"

say "== 3) services =="
mkdir -p "$ROOT/etc/systemd/system/multi-user.target.wants"
ln -sf /usr/lib/systemd/system/iwd.service "$ROOT/etc/systemd/system/multi-user.target.wants/iwd.service"
ln -sf /usr/lib/systemd/system/dhcpcd@.service "$ROOT/etc/systemd/system/multi-user.target.wants/dhcpcd@wlp1s0.service"

say "== 4) modules: drop the crashing PHY drivers =="
cat > "$ROOT/etc/modules-load.d/natrium.conf" <<'EOF'
# display
drm
msm
panel-sharp-td4722-xcmd
leds-qcom-lpg
# phy-qcom-qmp-combo / phy-qcom-qmp-usbc are NOT loaded: they oops
# (enable_irq on an unbalanced IRQ 70) in a kworker on this kernel.
EOF

say "== 5) gadget + debug files =="
install -m 755 "$AF/natrium-usb-gadget"         "$ROOT/usr/local/sbin/natrium-usb-gadget"
install -m 644 "$AF/natrium-usb-gadget.service" "$ROOT/etc/systemd/system/natrium-usb-gadget.service"
install -m 644 "$AF/20-usb0.network"            "$ROOT/etc/systemd/network/20-usb0.network"

say "== 6) regenerate image =="
rm -f /root/arch/arch-natrium-v5.img
bash "$TOOLS/build-arch-image.sh" "$ROOT" /root/arch/arch-natrium-v5.img 3G 2>&1 | tail -12
mv /mnt/c/Users/Public/natrium/arch/arch-natrium.img /mnt/c/Users/Public/natrium/arch/arch-natrium-v5.img 2>/dev/null || true
e2fsck -fn /root/arch/arch-natrium-v5.img >/tmp/v5fsck.log 2>&1; echo "fsck:"; tail -3 /tmp/v5fsck.log
say "ready"
