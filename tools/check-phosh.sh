#!/bin/sh
sleep 5
echo "=== procs ==="
ps aux 2>/dev/null | grep -E 'phoc|phosh|gnome-session|squeekboard' | grep -v grep
echo "=== session log ==="
tail -20 /tmp/phosh-tty1.log 2>&1
echo "=== seat ==="
loginctl list-sessions --no-legend 2>&1
echo "=== drm ==="
cat /sys/class/drm/card0-DSI-1/status 2>/dev/null
