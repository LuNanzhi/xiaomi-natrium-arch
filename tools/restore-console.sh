#!/bin/sh
# Put tty1 back to a normal login prompt (no autologin, no compositor loop).
rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf
rmdir /etc/systemd/system/getty@tty1.service.d 2>/dev/null
cat > /home/arch/.bash_profile <<'EOF'
# nothing automatic
EOF
chown arch:arch /home/arch/.bash_profile
pkill -9 -f phoc 2>/dev/null
pkill -9 -f phosh-session 2>/dev/null
systemctl daemon-reload
systemctl reset-failed getty@tty1.service 2>/dev/null
systemctl restart getty@tty1.service
sleep 2
echo "getty@tty1: $(systemctl is-active getty@tty1)"
echo "--- state ---"
uptime
df -h / | tail -1
