#!/bin/sh
# Install a screenshot tool and capture the current X root window.
export http_proxy=http://172.16.42.102:3128
export https_proxy=$http_proxy
command -v import >/dev/null 2>&1 || pacman -S --noconfirm imagemagick 2>&1 | tail -2

su - arch -c 'DISPLAY=:0 import -window root /tmp/shot.png' 2>&1
ls -l /tmp/shot.png 2>&1
echo "=== procs ==="
ps aux 2>/dev/null | grep -E 'onboard|i3|xterm|Xorg' | grep -v grep | head -8
echo "=== xrandr ==="
su - arch -c 'DISPLAY=:0 xrandr' 2>&1 | head -5
