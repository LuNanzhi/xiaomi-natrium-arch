#!/bin/bash
# Find where DRM returns -EBUSY for atomic commits.
cd /root/dt || exit 1
base="https://gitlab.com/msm8996-mainline/linux/-/raw/v6.19.5-msm8996/drivers/gpu/drm"
for f in drm_atomic.c drm_atomic_helper.c; do
    curl -sL --max-time 40 "$base/$f" -o "$f"
    echo "== $f ($(wc -l < "$f") lines)"
    grep -n 'EBUSY' "$f" | head -10
done
