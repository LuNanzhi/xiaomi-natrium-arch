#!/bin/sh
echo "=== who has card0 open ==="
fuser -v /dev/dri/card0 2>&1
for p in /proc/[0-9]*; do
  if ls -l "$p/fd" 2>/dev/null | grep -q 'dri/card0'; then
    echo "$(basename $p): $(tr '\0' ' ' < $p/cmdline)"
  fi
done
echo "=== drm debug state (first lines) ==="
head -30 /sys/kernel/debug/dri/0/state 2>&1
echo "=== dmesg msm tail ==="
dmesg 2>/dev/null | grep -iE 'msm|drm' | tail -10
