#!/bin/sh
# Turn on DRM atomic debug and see exactly which check returns EBUSY.
echo 0x1ff > /sys/module/drm/parameters/debug 2>/dev/null
su - arch -c 'XDG_RUNTIME_DIR=/run/user/1001 timeout 4 phoc -S -C /usr/share/phosh/phoc.ini' >/dev/null 2>&1
dmesg 2>/dev/null | grep -iE 'busy with a previous commit|Atomic|msm' | tail -25
echo 0 > /sys/module/drm/parameters/debug 2>/dev/null
