#!/usr/bin/env bash
# Inject a "dump diagnostics to the screen" hook into the Arch image.
# Handy when there is no keyboard, no serial and no USB network: the phone
# prints its own journal to tty0 a few seconds after boot, and you photograph it.
set -uo pipefail
IMG=${1:-/root/arch/arch-natrium.img}
MNT=/mnt/archdbg

mkdir -p "$MNT"
mount -o loop "$IMG" "$MNT" || { echo "mount failed"; exit 1; }

cat > "$MNT/usr/local/sbin/natrium-debug" <<'EOF'
#!/bin/sh
# dump everything useful to the local console
exec > /dev/tty0 2>&1
echo
echo "=================================================="
echo " NATRIUM DEBUG $(date)"
echo "=================================================="
echo "--- /sys/class/udc ---"
ls -l /sys/class/udc 2>&1
for f in /sys/class/udc/*/state; do [ -e "$f" ] && echo "$f = $(cat "$f" 2>&1)"; done
echo "--- gadget service ---"
systemctl status natrium-usb-gadget --no-pager -l 2>&1 | head -30
echo "--- modules ---"
lsmod 2>/dev/null | grep -E "libcomposite|rndis|u_ether|dwc3|typec|extcon" 2>&1
echo "--- dmesg (usb) ---"
dmesg 2>/dev/null | grep -iE "dwc3|udc|gadget|configfs|typec|extcon|usb" | tail -40
echo "--- journal (last 60) ---"
journalctl -b --no-pager -n 60 2>&1
echo "=================================================="
echo " END DEBUG"
echo "=================================================="
EOF
chmod 755 "$MNT/usr/local/sbin/natrium-debug"

cat > "$MNT/etc/systemd/system/natrium-debug.service" <<'EOF'
[Unit]
Description=Dump diagnostics to the console
After=multi-user.target natrium-usb-gadget.service
Wants=natrium-usb-gadget.service

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 25
ExecStart=/usr/local/sbin/natrium-debug
StandardOutput=tty
TTYPath=/dev/tty0

[Install]
WantedBy=multi-user.target
EOF

mkdir -p "$MNT/etc/systemd/system/multi-user.target.wants"
ln -sf /etc/systemd/system/natrium-debug.service "$MNT/etc/systemd/system/multi-user.target.wants/natrium-debug.service"

ls -l "$MNT/usr/local/sbin/natrium-debug" "$MNT/etc/systemd/system/natrium-debug.service"
sync
umount "$MNT"
e2fsck -f -y "$IMG" >/dev/null 2>&1
cp "$IMG" /mnt/c/Users/Public/natrium/arch/arch-natrium-dbg.img
echo "ready: /mnt/c/Users/Public/natrium/arch/arch-natrium-dbg.img"
