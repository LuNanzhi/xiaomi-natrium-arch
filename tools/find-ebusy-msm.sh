#!/bin/bash
# Look for -EBUSY in the msm DRM driver files (that is where the compositor's
# atomic commit would get "Device or resource busy" from).
cd /root/dt || exit 1
base="https://gitlab.com/msm8996-mainline/linux/-/raw/v6.19.5-msm8996/drivers/gpu/drm/msm"
for f in msm_kms.c msm_drv.c disp/mdp5/mdp5_kms.c disp/mdp5/mdp5_crtc.c dsi/dsi.c dsi/dsi_host.c; do
    out=$(echo "$f" | tr '/' '_')
    curl -sL --max-time 40 "$base/$f" -o "$out"
    n=$(grep -c 'EBUSY' "$out" 2>/dev/null)
    echo "== $f ($(wc -l < "$out") lines) EBUSY=$n"
    grep -n -B3 -A3 'EBUSY' "$out" 2>/dev/null | head -20
done
