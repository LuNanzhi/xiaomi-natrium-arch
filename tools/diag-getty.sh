#!/bin/sh
echo "=== getty@tty1 ==="
systemctl status getty@tty1 --no-pager -l 2>&1 | tail -12
echo "=== processes ==="
ps aux 2>/dev/null | grep -E 'agetty|phoc|phosh|gnome-session' | grep -v grep
echo "=== tty1 owner ==="
ls -l /dev/tty1
echo "=== journal dir ==="
ls -ld /var/log/journal 2>&1
echo "=== recent kernel/user msgs ==="
dmesg 2>/dev/null | tail -3
