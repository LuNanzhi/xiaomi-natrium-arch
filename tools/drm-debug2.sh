#!/bin/sh
echo 0x1ff > /sys/module/drm/parameters/debug 2>/dev/null
su - arch -c 'XDG_RUNTIME_DIR=/run/user/1001 timeout 4 phoc -S -C /usr/share/phosh/phoc.ini' >/dev/null 2>&1
echo "=== count busy-with-previous-commit ==="
dmesg 2>/dev/null | grep -c "busy with a previous commit"
echo "=== first 6 occurrences ==="
dmesg 2>/dev/null | grep "busy with a previous commit" | head -6
echo "=== other atomic failures ==="
dmesg 2>/dev/null | grep -iE "atomic.*(fail|busy)" | head -6
echo 0 > /sys/module/drm/parameters/debug 2>/dev/null
