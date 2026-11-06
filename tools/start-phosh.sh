#!/bin/sh
# Start a phosh session for user "arch" on tty1 (no display manager).
mkdir -p /run/user/1001
chown arch:arch /run/user/1001
chmod 700 /run/user/1001

pkill -f phoc 2>/dev/null
pkill -f phosh 2>/dev/null
sleep 1

su - arch -c 'XDG_RUNTIME_DIR=/run/user/1001 dbus-run-session -- phosh-session' > /tmp/phosh-run.log 2>&1 &
sleep 12

echo "--- log ---"
tail -20 /tmp/phosh-run.log
echo "--- procs ---"
pgrep -a phoc | head -2
pgrep -a phosh | head -3
echo "--- drm ---"
cat /sys/class/drm/card0-DSI-1/status 2>/dev/null
