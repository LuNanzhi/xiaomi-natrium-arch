#!/bin/bash
cd /root/dt || exit 1
base="https://gitlab.com/msm8996-mainline/linux/-/raw/v6.19.5-msm8996/drivers/gpu/drm"
for f in drm_atomic_uapi.c drm_atomic_helper.c; do
    curl -sL --max-time 40 "$base/$f" -o "u_$f"
    echo "== $f EBUSY:"
    grep -n 'EBUSY' "u_$f" | head -12
done
echo "=== drm_mode_atomic_ioctl tail ==="
grep -n 'drm_mode_atomic_ioctl' -A 120 "u_drm_atomic_uapi.c" | sed -n '95,125p'
