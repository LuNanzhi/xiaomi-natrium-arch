#!/bin/sh
echo "=== journal: phosh/phoc/gnome-session ==="
journalctl -b --no-pager 2>/dev/null | grep -iE 'phosh|phoc|gnome-session|squeekboard' | tail -40
echo
echo "=== journal: user session ==="
journalctl -b --no-pager -t gnome-session 2>/dev/null | tail -20
echo
echo "=== log file (append mode check) ==="
tail -40 /tmp/phosh-tty1.log 2>&1
