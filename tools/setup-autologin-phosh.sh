#!/bin/sh
# Set up tty1 autologin -> phosh session (proper logind seat, so gnome-session works).
set -e

mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin arch --noclear %I $TERM
Type=idle
EOF

cat > /home/arch/.bash_profile <<'EOF'
# start the phosh session on tty1 only
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec dbus-run-session -- phosh-session
fi
EOF
chown arch:arch /home/arch/.bash_profile

# keep a plain console on tty2 as an escape hatch
systemctl enable getty@tty2.service 2>/dev/null || true

systemctl daemon-reload
systemctl enable getty@tty1.service 2>/dev/null || true
loginctl enable-linger arch 2>/dev/null || true

echo "--- autologin unit ---"
cat /etc/systemd/system/getty@tty1.service.d/autologin.conf
echo "--- profile ---"
cat /home/arch/.bash_profile
echo "--- tty1 status ---"
systemctl is-enabled getty@tty1.service
