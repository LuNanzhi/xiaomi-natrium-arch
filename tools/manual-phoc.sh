#!/bin/sh
# Stop the restart loop and run phoc manually to capture its real error.
cat > /home/arch/.bash_profile <<'EOF'
# console only for now
EOF
chown arch:arch /home/arch/.bash_profile

pkill -9 -f phoc 2>/dev/null
pkill -9 -f phosh-session 2>/dev/null
sleep 1
systemctl reset-failed getty@tty1.service 2>/dev/null
systemctl restart getty@tty1.service
sleep 2

echo "=== manual phoc run (10s) ==="
su - arch -c 'XDG_RUNTIME_DIR=/run/user/1001 timeout 10 phoc -S -C /usr/share/phosh/phoc.ini' > /tmp/phoc-manual.log 2>&1
tail -40 /tmp/phoc-manual.log
