#!/bin/sh
echo "=== onboard proc ==="
pgrep -a onboard | head -2
echo "=== onboard log ==="
tail -10 /tmp/onboard.log 2>/dev/null
echo "=== window geometry ==="
su - arch -c 'DISPLAY=:0 xwininfo -root -tree 2>/dev/null' | grep -i -B1 -A4 onboard | head -20
echo "=== all windows ==="
su - arch -c 'DISPLAY=:0 xwininfo -root -tree 2>/dev/null' | grep -E '^\s+0x' | head -10
