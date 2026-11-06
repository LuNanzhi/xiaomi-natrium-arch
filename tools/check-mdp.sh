#!/bin/sh
echo "=== pp done timeouts (total) ==="
dmesg 2>/dev/null | grep -c "pp done time out"
echo "=== last msm messages ==="
dmesg 2>/dev/null | grep -iE 'pp done|mdp|dsi|panel' | tail -8
echo "=== run phoc 6s and re-count ==="
before=$(dmesg 2>/dev/null | grep -c "pp done time out")
su - arch -c 'XDG_RUNTIME_DIR=/run/user/1001 timeout 6 phoc -S -C /usr/share/phosh/phoc.ini' >/dev/null 2>&1
after=$(dmesg 2>/dev/null | grep -c "pp done time out")
echo "before=$before after=$after"
