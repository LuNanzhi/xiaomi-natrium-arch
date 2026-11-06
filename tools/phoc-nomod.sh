#!/bin/sh
# Fix the runtime dir ownership, then run phoc with the compat switches and
# check whether it stays alive (that is what "working" looks like).
pkill -9 -f phoc 2>/dev/null
sleep 1
mkdir -p /run/user/1001
chown -R arch:arch /run/user/1001
chmod 700 /run/user/1001

su - arch -c 'XDG_RUNTIME_DIR=/run/user/1001 WLR_DRM_NO_MODIFIERS=1 WLR_NO_HARDWARE_CURSORS=1 nohup phoc -S -C /usr/share/phosh/phoc.ini' > /tmp/phoc-ok.log 2>&1 &
sleep 10

if pgrep -f "phoc -S" >/dev/null; then
    echo "RESULT: phoc is STILL RUNNING after 10s"
else
    echo "RESULT: phoc exited"
fi
echo "=== log ==="
grep -vE "dconf-CRITICAL" /tmp/phoc-ok.log | tail -25
echo "=== atomic failures ==="
grep -c "Atomic commit failed" /tmp/phoc-ok.log
echo "=== drm state ==="
cat /sys/kernel/debug/dri/0/state 2>/dev/null | head -6
