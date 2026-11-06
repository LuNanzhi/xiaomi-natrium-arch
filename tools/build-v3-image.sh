#!/usr/bin/env bash
# v3: fix the USB gadget on the installed Arch image.
#   - load the QMP PHY drivers that dwc3-qcom needs (they are modules!)
#   - ship the gadget script that waits for the UDC instead of failing at once
#   - keep the console debug dump
set -uo pipefail
SRC=${1:-/root/arch/arch-natrium.img}
DST=${2:-/root/arch/arch-natrium-v3.img}
MNT=/mnt/archv3

cp "$SRC" "$DST"
mkdir -p "$MNT"
mount -o loop "$DST" "$MNT" || { echo "mount failed"; exit 1; }

cat > "$MNT/etc/modules-load.d/natrium.conf" <<'EOF'
# display
drm
msm
panel-sharp-td4722-xcmd
leds-qcom-lpg
# USB: dwc3-qcom is builtin but defers probe until these PHY drivers are loaded,
# and without a UDC the gadget can never bind
phy-qcom-qmp-combo
phy-qcom-qmp-usbc
EOF

install -m 755 "/mnt/c/Users/江月白/Documents/deepseek-harness/default-workspace/natrium-port/arch-files/natrium-usb-gadget" \
    "$MNT/usr/local/sbin/natrium-usb-gadget"
install -m 644 "/mnt/c/Users/江月白/Documents/deepseek-harness/default-workspace/natrium-port/arch-files/natrium-usb-gadget.service" \
    "$MNT/etc/systemd/system/natrium-usb-gadget.service"
install -m 644 "/mnt/c/Users/江月白/Documents/deepseek-harness/default-workspace/natrium-port/arch-files/20-usb0.network" \
    "$MNT/etc/systemd/network/20-usb0.network"

echo "--- modules-load.d ---"; cat "$MNT/etc/modules-load.d/natrium.conf"
echo "--- gadget script head ---"; head -3 "$MNT/usr/local/sbin/natrium-usb-gadget"
grep -c "wait for it" "$MNT/usr/local/sbin/natrium-usb-gadget" >/dev/null 2>&1 || true

sync
umount "$MNT"
e2fsck -f -y "$DST" >/dev/null 2>&1
cp "$DST" /mnt/c/Users/Public/natrium/arch/arch-natrium-v3.img
echo "ready: /mnt/c/Users/Public/natrium/arch/arch-natrium-v3.img"
