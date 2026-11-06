#!/bin/sh
# Full phosh session on tty1 with the wlroots compat switches.
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin arch --noclear %I $TERM
Type=idle
EOF

cat > /home/arch/.bash_profile <<'EOF'
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    export WLR_DRM_NO_MODIFIERS=1
    export WLR_NO_HARDWARE_CURSORS=1
    export XDG_RUNTIME_DIR=/run/user/1001
    exec dbus-run-session -- phosh-session
fi
EOF
chown arch:arch /home/arch/.bash_profile

pkill -9 -f phoc 2>/dev/null
pkill -9 -f phosh 2>/dev/null
systemctl daemon-reload
systemctl reset-failed getty@tty1.service 2>/dev/null
systemctl restart getty@tty1.service
sleep 20

echo "=== procs ==="
ps aux 2>/dev/null | grep -E 'phoc|phosh|gnome-session|squeekboard' | grep -v grep
echo "=== session ==="
timeout 6 loginctl list-sessions --no-legend 2>&1 | head -4
