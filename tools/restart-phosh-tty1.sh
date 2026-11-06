#!/bin/sh
# Replace the aggressive exec with a version that logs and falls back to a shell.
cat > /home/arch/.bash_profile <<'EOF'
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    echo "starting phosh-session at $(date)" > /tmp/phosh-tty1.log
    dbus-run-session -- phosh-session >> /tmp/phosh-tty1.log 2>&1
    echo "phosh-session exited rc=$? at $(date)" >> /tmp/phosh-tty1.log
    exec bash -l
fi
EOF
chown arch:arch /home/arch/.bash_profile

systemctl reset-failed getty@tty1.service
systemctl restart getty@tty1.service
sleep 15

echo "=== phosh log ==="
tail -30 /tmp/phosh-tty1.log 2>&1
echo "=== procs ==="
ps aux 2>/dev/null | grep -E 'phoc|phosh' | grep -v grep
