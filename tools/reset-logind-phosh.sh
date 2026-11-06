#!/bin/sh
# logind looks stuck (loginctl times out). Restart it, clear stray compositors,
# then bring the tty1 session up again.
pkill -9 -f phoc 2>/dev/null
pkill -9 -f phosh-session 2>/dev/null
sleep 1

systemctl restart systemd-logind 2>&1
sleep 3
echo "logind: $(systemctl is-active systemd-logind)"

systemctl reset-failed getty@tty1.service 2>/dev/null
systemctl restart getty@tty1.service
sleep 12

echo "=== loginctl ==="
timeout 8 loginctl list-sessions --no-legend 2>&1
echo "=== procs ==="
ps aux 2>/dev/null | grep -E 'phoc|phosh|gnome-session' | grep -v grep
echo "=== log ==="
tail -15 /tmp/phosh-tty1.log 2>&1
