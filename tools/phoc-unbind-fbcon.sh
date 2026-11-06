#!/bin/sh
# Unbind the fbdev console from the DRM device, then start phoc.
for v in /sys/class/vtconsole/vtcon*; do
    name=$(cat "$v/name" 2>/dev/null)
    echo "$v: $name"
    case "$name" in
        *frame*|*fb*)
            echo 0 > "$v/bind" 2>/dev/null && echo "  unbound"
            ;;
    esac
done

pkill -9 -f phoc 2>/dev/null
sleep 1

echo "=== phoc with fbcon unbound ==="
su - arch -c 'XDG_RUNTIME_DIR=/run/user/1001 timeout 12 phoc -S -C /usr/share/phosh/phoc.ini' > /tmp/phoc2.log 2>&1
grep -c "Atomic commit failed" /tmp/phoc2.log 2>/dev/null
tail -15 /tmp/phoc2.log
