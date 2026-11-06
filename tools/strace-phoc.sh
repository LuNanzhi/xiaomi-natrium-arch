#!/bin/sh
# Install strace (through the proxy) and capture phoc's DRM ioctls.
export http_proxy=http://172.16.42.102:3128
export https_proxy=http://172.16.42.102:3128
command -v strace >/dev/null 2>&1 || pacman -S --noconfirm strace 2>&1 | tail -2

pkill -9 -f phoc 2>/dev/null
sleep 1

su - arch -c 'XDG_RUNTIME_DIR=/run/user/1001 WLR_DRM_NO_MODIFIERS=1 WLR_NO_HARDWARE_CURSORS=1 timeout 5 strace -f -tt -e trace=ioctl -o /tmp/phoc.strace phoc -S -C /usr/share/phosh/phoc.ini' >/dev/null 2>&1

echo "=== ioctl lines: $(wc -l < /tmp/phoc.strace 2>/dev/null) ==="
echo "=== failed DRM ioctls ==="
grep -E 'ioctl\(.*(EBUSY|EINVAL|EACCES)' /tmp/phoc.strace 2>/dev/null | tail -12
echo "=== DRM_IOCTL_MODE_ATOMIC results ==="
grep -E 'DRM_IOCTL_MODE_ATOMIC' /tmp/phoc.strace 2>/dev/null | tail -6
