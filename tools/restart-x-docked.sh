#!/bin/sh
# Restart the X session so i3 (inside dbus-run-session) launches onboard again,
# this time with docking enabled from dconf.
su - arch -c 'DISPLAY=:0 i3-msg exit' >/dev/null 2>&1
sleep 15

echo "=== procs ==="
ps aux 2>/dev/null | grep -E "Xorg|/i3|onboard" | grep -v grep | head -6
echo "=== windows ==="
su - arch -c 'DISPLAY=:0 xwininfo -root -tree' 2>/dev/null | grep -iE 'onboard|xterm' | head -5
su - arch -c 'DISPLAY=:0 import -window root /tmp/shot10.png' 2>&1
ls -l /tmp/shot10.png 2>&1
