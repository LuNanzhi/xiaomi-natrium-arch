#!/bin/sh
echo "=== processes ==="
ps aux 2>/dev/null | grep -E 'phoc|phosh|gnome-session|squeekboard|gsd-' | grep -v grep
echo
echo "=== phoc log (non-atomic lines) ==="
grep -vE "Atomic commit failed|dconf-CRITICAL" /tmp/phoc-ok.log 2>/dev/null | tail -25
echo
echo "=== atomic fail count so far ==="
grep -c "Atomic commit failed" /tmp/phoc-ok.log 2>/dev/null
echo
echo "=== session ==="
timeout 6 loginctl list-sessions --no-legend 2>&1
