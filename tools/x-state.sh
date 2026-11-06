#!/bin/sh
echo "=== X processes ==="
ps aux 2>/dev/null | grep -E "Xorg|/i3|onboard|xterm" | grep -v grep | head -10
echo "=== x session alive? ==="
su - arch -c 'DISPLAY=:0 xdpyinfo 2>&1 | head -3' 2>&1
echo "=== i3 log ==="
tail -10 /tmp/i3log 2>/dev/null
ls -l /tmp/shot2.png 2>&1
