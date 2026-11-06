#!/bin/sh
# Try wlroots compatibility switches that are commonly needed on msm8996.
run() {
    label=$1; shift
    out=$(su - arch -c "XDG_RUNTIME_DIR=/run/user/1001 env $* timeout 6 phoc -S -C /usr/share/phosh/phoc.ini" 2>&1)
    n=$(printf '%s' "$out" | grep -c "Atomic commit failed")
    ok=$(printf '%s' "$out" | grep -c "fatal\|Failed to")
    echo "$label: atomic_fail=$n other=$ok"
    printf '%s\n' "$out" | grep -vE "Atomic commit failed" | head -5
}

run "no-modifiers"      "WLR_DRM_NO_MODIFIERS=1"
run "no-hw-cursors"     "WLR_NO_HARDWARE_CURSORS=1"
run "both"              "WLR_DRM_NO_MODIFIERS=1 WLR_NO_HARDWARE_CURSORS=1"
run "gles2"             "WLR_RENDERER=gles2 WLR_DRM_NO_MODIFIERS=1 WLR_NO_HARDWARE_CURSORS=1"
